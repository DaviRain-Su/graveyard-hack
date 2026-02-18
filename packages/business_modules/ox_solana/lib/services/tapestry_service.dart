import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tapestry Deep Integration — On-chain Social Graph for 0xchat
///
/// Tapestry (usetapestry.dev) uses state compression + Merkle trees on Solana
/// to store social graph data on-chain (same tech as compressed NFTs).
///
/// Features integrated:
/// 1. **Profiles** — Create/read/update/search user identities
/// 2. **Follows** — On-chain follow/unfollow with follower/following lists
/// 3. **Content** — Post/read social content (transactions, NFTs, etc.)
/// 4. **Likes** — Like/unlike content
/// 5. **Comments** — Comment on content
/// 6. **Search** — Cross-app user discovery + suggested friends
///
/// Architecture: **Local-first with Tapestry API sync**
/// - Local cache always works (SharedPreferences)
/// - Tapestry API syncs to on-chain social graph when API key is available
class TapestryService extends ChangeNotifier {
  static final TapestryService instance = TapestryService._();
  TapestryService._();

  static const String _baseUrl = 'https://api.usetapestry.dev/v1';
  static const String _storageKey = 'ox_solana_tapestry_profile';
  static const String _localBindingsKey = 'ox_solana_local_bindings';
  static const String _apiKeyStorageKey = 'ox_solana_tapestry_api_key';
  static const String _followCacheKey = 'ox_solana_tapestry_follows';

  String? _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  String? _profileId;
  String? get profileId => _profileId;

  TapestryProfile? _profile;
  TapestryProfile? get profile => _profile;

  // Social counts
  int _followersCount = 0;
  int _followingCount = 0;
  int get followersCount => _followersCount;
  int get followingCount => _followingCount;

  // Local Nostr pubkey → Solana address cache
  Map<String, String> _localBindings = {};
  Map<String, String> get localBindings => Map.unmodifiable(_localBindings);

  // Follow cache (profileId -> bool)
  Set<String> _followingCache = {};
  bool isFollowingCached(String profileId) => _followingCache.contains(profileId);

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get hasBoundProfile => _profileId != null || _localBindings.isNotEmpty;

  /// Initialize — load saved bindings and optionally API key
  Future<void> init({String? apiKey}) async {
    final prefs = await SharedPreferences.getInstance();

    // Load API key from param → storage → null
    _apiKey = apiKey ?? prefs.getString(_apiKeyStorageKey);

    // Load local bindings cache
    final bindingsJson = prefs.getString(_localBindingsKey);
    if (bindingsJson != null) {
      try {
        _localBindings = Map<String, String>.from(jsonDecode(bindingsJson));
      } catch (_) {
        _localBindings = {};
      }
    }

    // Load follow cache
    final followJson = prefs.getString(_followCacheKey);
    if (followJson != null) {
      try {
        _followingCache = Set<String>.from(jsonDecode(followJson));
      } catch (_) {
        _followingCache = {};
      }
    }

    // Load Tapestry profile ID
    _profileId = prefs.getString(_storageKey);
    if (_profileId != null && hasApiKey) {
      await fetchProfile();
    }

    if (kDebugMode) {
      print('[Tapestry] Init: ${_localBindings.length} bindings, ${_followingCache.length} following, API: ${hasApiKey}');
    }
  }

  /// Set API key (from settings UI)
  Future<void> setApiKey(String? key) async {
    _apiKey = (key?.isNotEmpty == true) ? key : null;
    final prefs = await SharedPreferences.getInstance();
    if (_apiKey != null) {
      await prefs.setString(_apiKeyStorageKey, _apiKey!);
    } else {
      await prefs.remove(_apiKeyStorageKey);
    }
    notifyListeners();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  String _withApiKey(String url) {
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}apiKey=$_apiKey';
  }

  // ═══════════════════════════════════════════════════════
  // 1. PROFILES — Identity management
  // ═══════════════════════════════════════════════════════

  /// Create or find profile using findOrCreate (Tapestry official pattern)
  Future<TapestryProfile?> findOrCreateProfile({
    required String walletAddress,
    required String username,
    String? bio,
    String? profileImage,
    String? nostrPubkey,
    Map<String, String>? customProperties,
  }) async {
    // Always save locally first
    if (nostrPubkey != null) {
      await bindLocal(nostrPubkey: nostrPubkey, solanaAddress: walletAddress);
    }

    if (!hasApiKey) {
      if (kDebugMode) print('[Tapestry] No API key — saved locally only');
      _profile = TapestryProfile(
        id: username,
        username: username,
        bio: bio ?? 'Nostr + Solana identity (local)',
        walletAddress: walletAddress,
        blockchain: 'SOLANA',
        customProperties: {
          if (nostrPubkey != null) 'nostr_pubkey': nostrPubkey,
          if (profileImage != null) 'profileImage': profileImage,
          ...?customProperties,
        },
        isLocal: true,
      );
      _profileId = username;
      notifyListeners();
      return _profile;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final body = {
        'walletAddress': walletAddress,
        'username': username,
        if (bio != null) 'bio': bio,
        'blockchain': 'SOLANA',
        'execution': 'FAST_UNCONFIRMED',
        'customProperties': [
          if (nostrPubkey != null)
            {'key': 'nostr_pubkey', 'value': nostrPubkey},
          if (profileImage != null)
            {'key': 'profileImage', 'value': profileImage},
          {'key': 'platform', 'value': '0xchat'},
          {'key': 'created_at', 'value': DateTime.now().toIso8601String()},
          if (customProperties != null)
            ...customProperties.entries.map((e) => {'key': e.key, 'value': e.value}),
        ],
      };

      final response = await http.post(
        Uri.parse(_withApiKey('$_baseUrl/profiles/findOrCreate')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('[Tapestry] findOrCreate: ${response.statusCode}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _profile = TapestryProfile.fromApiResponse(data);
        _profileId = _profile!.id ?? username;

        // Update social counts
        final counts = data['socialCounts'] ?? {};
        _followersCount = counts['followers'] ?? 0;
        _followingCount = counts['following'] ?? 0;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, _profileId!);

        return _profile;
      } else {
        if (kDebugMode) {
          print('[Tapestry] findOrCreate failed: ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] findOrCreate error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _profile;
  }

  /// Fetch existing profile from Tapestry API
  Future<TapestryProfile?> fetchProfile() async {
    if (_profileId == null || !hasApiKey) return null;

    try {
      final response = await http.get(
        Uri.parse(_withApiKey('$_baseUrl/profiles/$_profileId')),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profileData = data['profile'] ?? data;
        _profile = TapestryProfile.fromApiResponse(profileData);

        // Update social counts
        final counts = data['socialCounts'] ?? {};
        _followersCount = counts['followers'] ?? 0;
        _followingCount = counts['following'] ?? 0;

        notifyListeners();
        return _profile;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Fetch error: $e');
    }
    return null;
  }

  /// Update profile
  Future<bool> updateProfile({
    String? username,
    String? bio,
    String? profileImage,
    Map<String, String>? customProperties,
  }) async {
    if (_profileId == null || !hasApiKey) return false;

    try {
      final body = {
        'id': _profileId,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (profileImage != null || customProperties != null)
          'customProperties': [
            if (profileImage != null)
              {'key': 'profileImage', 'value': profileImage},
            if (customProperties != null)
              ...customProperties.entries.map((e) => {'key': e.key, 'value': e.value}),
          ],
      };

      final response = await http.put(
        Uri.parse(_withApiKey('$_baseUrl/profiles/update')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchProfile(); // Refresh
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Update error: $e');
    }
    return false;
  }

  /// Search profiles across all apps on Tapestry
  Future<List<TapestryProfile>> searchProfiles(String query, {bool includeExternal = true}) async {
    if (!hasApiKey) return [];

    try {
      final url = _withApiKey(
        '$_baseUrl/profiles/search?shouldIncludeExternalProfiles=$includeExternal'
      );
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profiles = data['profiles'] as List? ?? data as List? ?? [];
        return profiles.map<TapestryProfile>((p) =>
          TapestryProfile.fromApiResponse(p as Map<String, dynamic>)
        ).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Search error: $e');
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════
  // 2. FOLLOWS — On-chain social connections
  // ═══════════════════════════════════════════════════════

  /// Follow a user
  Future<bool> followUser(String targetProfileId) async {
    if (_profileId == null || !hasApiKey) return false;

    try {
      final body = {
        'followerProfileId': _profileId,
        'followeeProfileId': targetProfileId,
      };

      final response = await http.post(
        Uri.parse(_withApiKey('$_baseUrl/followers')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _followingCache.add(targetProfileId);
        _followingCount++;
        await _saveFollowCache();
        notifyListeners();
        if (kDebugMode) print('[Tapestry] Followed: $targetProfileId');
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Follow error: $e');
    }
    return false;
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String targetProfileId) async {
    if (_profileId == null || !hasApiKey) return false;

    try {
      final body = {
        'followerProfileId': _profileId,
        'followeeProfileId': targetProfileId,
      };

      final response = await http.delete(
        Uri.parse(_withApiKey('$_baseUrl/followers')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _followingCache.remove(targetProfileId);
        _followingCount = (_followingCount - 1).clamp(0, 999999);
        await _saveFollowCache();
        notifyListeners();
        if (kDebugMode) print('[Tapestry] Unfollowed: $targetProfileId');
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Unfollow error: $e');
    }
    return false;
  }

  /// Check if following a user
  Future<bool> isFollowing(String targetProfileId) async {
    // Check cache first
    if (_followingCache.contains(targetProfileId)) return true;

    if (_profileId == null || !hasApiKey) return false;

    try {
      final response = await http.get(
        Uri.parse(_withApiKey(
          '$_baseUrl/followers/check?followerId=$_profileId&followeeId=$targetProfileId'
        )),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isFollowing = data['isFollowing'] == true;
        if (isFollowing) {
          _followingCache.add(targetProfileId);
          await _saveFollowCache();
        }
        return isFollowing;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Check follow error: $e');
    }
    return false;
  }

  /// Get followers list
  Future<List<TapestryProfile>> getFollowers({int limit = 20, int offset = 0}) async {
    if (_profileId == null || !hasApiKey) return [];

    try {
      final response = await http.get(
        Uri.parse(_withApiKey(
          '$_baseUrl/profiles/followers/$_profileId?limit=$limit&offset=$offset'
        )),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final followers = data['followers'] as List? ?? data as List? ?? [];
        return followers.map<TapestryProfile>((p) =>
          TapestryProfile.fromApiResponse(p as Map<String, dynamic>)
        ).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Get followers error: $e');
    }
    return [];
  }

  /// Get following list
  Future<List<TapestryProfile>> getFollowing({int limit = 20, int offset = 0}) async {
    if (_profileId == null || !hasApiKey) return [];

    try {
      final response = await http.get(
        Uri.parse(_withApiKey(
          '$_baseUrl/profiles/following/$_profileId?limit=$limit&offset=$offset'
        )),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final following = data['following'] as List? ?? data as List? ?? [];
        return following.map<TapestryProfile>((p) =>
          TapestryProfile.fromApiResponse(p as Map<String, dynamic>)
        ).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Get following error: $e');
    }
    return [];
  }

  /// Get follower/following counts
  Future<void> refreshSocialCounts() async {
    if (_profileId == null || !hasApiKey) return;

    try {
      final futures = await Future.wait([
        http.get(
          Uri.parse(_withApiKey('$_baseUrl/profiles/followers/$_profileId/count')),
          headers: _headers,
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse(_withApiKey('$_baseUrl/profiles/following/$_profileId/count')),
          headers: _headers,
        ).timeout(const Duration(seconds: 10)),
      ]);

      if (futures[0].statusCode == 200) {
        final data = jsonDecode(futures[0].body);
        _followersCount = data['count'] ?? data as int? ?? 0;
      }
      if (futures[1].statusCode == 200) {
        final data = jsonDecode(futures[1].body);
        _followingCount = data['count'] ?? data as int? ?? 0;
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Social counts error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // 3. CONTENT — Social feed (tx shares, NFT shares, etc.)
  // ═══════════════════════════════════════════════════════

  /// Create content (post a transaction, share NFT, etc.)
  Future<TapestryContent?> createContent({
    required String contentType, // 'transaction', 'nft_share', 'music_share', 'text_post'
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    if (_profileId == null || !hasApiKey) return null;

    try {
      final body = {
        'profileId': _profileId,
        'contentType': contentType,
        'text': text,
        'properties': {
          'platform': '0xchat',
          'created_at': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      };

      final response = await http.post(
        Uri.parse(_withApiKey('$_baseUrl/contents/create')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('[Tapestry] Content created: ${data['id']}');
        return TapestryContent.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Create content error: $e');
    }
    return null;
  }

  /// Get user's content feed
  Future<List<TapestryContent>> getUserContent(String profileId, {int limit = 10, int offset = 0}) async {
    if (!hasApiKey) return [];

    try {
      final response = await http.get(
        Uri.parse(_withApiKey(
          '$_baseUrl/contents/profile/$profileId?limit=$limit&offset=$offset'
        )),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contents = data['contents'] as List? ?? data as List? ?? [];
        return contents.map<TapestryContent>((c) =>
          TapestryContent.fromJson(c as Map<String, dynamic>)
        ).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Get content error: $e');
    }
    return [];
  }

  /// Get single content by ID
  Future<TapestryContent?> getContent(String contentId) async {
    if (!hasApiKey) return null;

    try {
      final response = await http.get(
        Uri.parse(_withApiKey('$_baseUrl/contents/$contentId')),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TapestryContent.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Get content error: $e');
    }
    return null;
  }

  /// Delete content
  Future<bool> deleteContent(String contentId) async {
    if (!hasApiKey) return false;

    try {
      final response = await http.delete(
        Uri.parse(_withApiKey('$_baseUrl/contents/delete')),
        headers: _headers,
        body: jsonEncode({'contentId': contentId}),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Delete content error: $e');
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════
  // 4. LIKES — Social engagement
  // ═══════════════════════════════════════════════════════

  /// Like a content
  Future<bool> likeContent(String contentId) async {
    if (_profileId == null || !hasApiKey) return false;

    try {
      final body = {
        'profileId': _profileId,
        'contentId': contentId,
      };

      final response = await http.post(
        Uri.parse(_withApiKey('$_baseUrl/likes')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) print('[Tapestry] Liked: $contentId');
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Like error: $e');
    }
    return false;
  }

  /// Unlike a content
  Future<bool> unlikeContent(String contentId) async {
    if (_profileId == null || !hasApiKey) return false;

    try {
      final body = {
        'profileId': _profileId,
        'contentId': contentId,
      };

      final response = await http.delete(
        Uri.parse(_withApiKey('$_baseUrl/likes')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Unlike error: $e');
    }
    return false;
  }

  /// Check if user liked a content
  Future<bool> hasLiked(String contentId) async {
    if (_profileId == null || !hasApiKey) return false;

    try {
      final response = await http.get(
        Uri.parse(_withApiKey(
          '$_baseUrl/likes/check?profileId=$_profileId&contentId=$contentId'
        )),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['hasLiked'] == true;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Check like error: $e');
    }
    return false;
  }

  /// Get like count for content
  Future<int> getLikeCount(String contentId) async {
    if (!hasApiKey) return 0;

    try {
      final response = await http.get(
        Uri.parse(_withApiKey('$_baseUrl/likes/count/$contentId')),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Like count error: $e');
    }
    return 0;
  }

  // ═══════════════════════════════════════════════════════
  // 5. COMMENTS — Discussion on content
  // ═══════════════════════════════════════════════════════

  /// Add a comment to content
  Future<TapestryComment?> addComment({
    required String contentId,
    required String text,
  }) async {
    if (_profileId == null || !hasApiKey) return null;

    try {
      final body = {
        'profileId': _profileId,
        'contentId': contentId,
        'text': text,
      };

      final response = await http.post(
        Uri.parse(_withApiKey('$_baseUrl/comments')),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('[Tapestry] Comment added');
        return TapestryComment.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Comment error: $e');
    }
    return null;
  }

  /// Get comments for content
  Future<List<TapestryComment>> getComments(String contentId, {int limit = 20, int offset = 0}) async {
    if (!hasApiKey) return [];

    try {
      final response = await http.get(
        Uri.parse(_withApiKey(
          '$_baseUrl/comments?contentId=$contentId&limit=$limit&offset=$offset'
        )),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final comments = data['comments'] as List? ?? data as List? ?? [];
        return comments.map<TapestryComment>((c) =>
          TapestryComment.fromJson(c as Map<String, dynamic>)
        ).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Get comments error: $e');
    }
    return [];
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    if (!hasApiKey) return false;

    try {
      final response = await http.delete(
        Uri.parse(_withApiKey('$_baseUrl/comments/$commentId')),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Delete comment error: $e');
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════
  // LOCAL BINDING (always works without API key)
  // ═══════════════════════════════════════════════════════

  /// Bind a Nostr pubkey to a Solana address (local cache)
  Future<void> bindLocal({
    required String nostrPubkey,
    required String solanaAddress,
  }) async {
    _localBindings[nostrPubkey] = solanaAddress;
    await _saveLocalBindings();
    if (kDebugMode) {
      print('[Tapestry] Local bind: ${nostrPubkey.substring(0, 8)}... → ${solanaAddress.substring(0, 8)}...');
    }
  }

  /// Remove a local binding
  Future<void> unbindLocal(String nostrPubkey) async {
    _localBindings.remove(nostrPubkey);
    await _saveLocalBindings();
  }

  /// Resolve Nostr pubkey → Solana address (local first, then Tapestry API)
  Future<String?> resolveNostrToSolana(String nostrPubkey) async {
    // 1. Check local cache first (instant)
    final localAddr = _localBindings[nostrPubkey];
    if (localAddr != null) return localAddr;

    // 2. Try Tapestry API search
    if (hasApiKey) {
      try {
        final profiles = await searchProfiles(nostrPubkey);
        for (final p in profiles) {
          if (p.customProperties['nostr_pubkey'] == nostrPubkey && p.walletAddress != null) {
            await bindLocal(nostrPubkey: nostrPubkey, solanaAddress: p.walletAddress!);
            return p.walletAddress;
          }
        }
      } catch (e) {
        if (kDebugMode) print('[Tapestry] API resolve failed: $e');
      }
    }

    return null;
  }

  /// Resolve Solana address → Nostr pubkey (reverse lookup from local cache)
  String? resolveSolanaToNostr(String solanaAddress) {
    for (final entry in _localBindings.entries) {
      if (entry.value == solanaAddress) return entry.key;
    }
    return null;
  }

  /// Get all known contacts with Solana wallets
  List<MapEntry<String, String>> get knownSolanaContacts =>
      _localBindings.entries.toList();

  // ═══════════════════════════════════════════════════════
  // CONVENIENCE: Auto-post social content from actions
  // ═══════════════════════════════════════════════════════

  /// Auto-post when a transaction is sent (opt-in)
  Future<void> shareTransaction({
    required String signature,
    required double amount,
    required String tokenSymbol,
    required String toAddress,
    bool isDevnet = false,
  }) async {
    if (_profileId == null || !hasApiKey) return;

    await createContent(
      contentType: 'transaction',
      text: 'Sent $amount $tokenSymbol to ${toAddress.substring(0, 6)}...${toAddress.substring(toAddress.length - 4)}',
      metadata: {
        'signature': signature,
        'amount': amount.toString(),
        'token': tokenSymbol,
        'toAddress': toAddress,
        'network': isDevnet ? 'devnet' : 'mainnet-beta',
      },
    );
  }

  /// Auto-post when an NFT is shared
  Future<void> shareNft({
    required String nftName,
    required String nftImage,
    required String mintAddress,
  }) async {
    if (_profileId == null || !hasApiKey) return;

    await createContent(
      contentType: 'nft_share',
      text: 'Check out my NFT: $nftName 🖼️',
      metadata: {
        'nft_name': nftName,
        'nft_image': nftImage,
        'mint_address': mintAddress,
      },
    );
  }

  /// Auto-post when music is shared
  Future<void> shareMusicToFeed({
    required String trackTitle,
    required String artist,
    required String trackId,
  }) async {
    if (_profileId == null || !hasApiKey) return;

    await createContent(
      contentType: 'music_share',
      text: '🎵 Listening to "$trackTitle" by $artist on Audius',
      metadata: {
        'track_title': trackTitle,
        'artist': artist,
        'audius_track_id': trackId,
        'audius_url': 'https://audius.co/tracks/$trackId',
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════

  /// Clear all saved data
  Future<void> clearBinding() async {
    _profileId = null;
    _profile = null;
    _followersCount = 0;
    _followingCount = 0;
    _localBindings.clear();
    _followingCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_localBindingsKey);
    await prefs.remove(_followCacheKey);
    notifyListeners();
  }

  Future<void> _saveLocalBindings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localBindingsKey, jsonEncode(_localBindings));
  }

  Future<void> _saveFollowCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_followCacheKey, jsonEncode(_followingCache.toList()));
  }
}

// ═══════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════

/// Tapestry profile model (matches API response)
class TapestryProfile {
  final String? id;
  final String? username;
  final String? bio;
  final String? walletAddress;
  final String? blockchain;
  final String? namespace;
  final Map<String, dynamic> customProperties;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isLocal;

  TapestryProfile({
    this.id,
    this.username,
    this.bio,
    this.walletAddress,
    this.blockchain,
    this.namespace,
    this.customProperties = const {},
    this.createdAt,
    this.updatedAt,
    this.isLocal = false,
  });

  String? get nostrPubkey => customProperties['nostr_pubkey'] as String?;
  String? get profileImage => customProperties['profileImage'] as String?;

  factory TapestryProfile.fromApiResponse(Map<String, dynamic> json) {
    // Handle both nested {profile: {...}} and flat response
    final data = json['profile'] as Map<String, dynamic>? ?? json;

    return TapestryProfile(
      id: data['id']?.toString(),
      username: data['username'] as String?,
      bio: data['bio'] as String?,
      walletAddress: data['walletAddress'] as String?,
      blockchain: data['blockchain'] as String?,
      namespace: data['namespace'] as String?,
      customProperties: data['customProperties'] as Map<String, dynamic>? ?? {},
      createdAt: data['createdAt'] != null ? DateTime.tryParse(data['createdAt']) : null,
      updatedAt: data['updatedAt'] != null ? DateTime.tryParse(data['updatedAt']) : null,
      isLocal: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'bio': bio,
    'walletAddress': walletAddress,
    'blockchain': blockchain,
    'customProperties': customProperties,
  };
}

/// Tapestry content model
class TapestryContent {
  final String? id;
  final String? profileId;
  final String? contentType;
  final String? text;
  final Map<String, dynamic> properties;
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;

  TapestryContent({
    this.id,
    this.profileId,
    this.contentType,
    this.text,
    this.properties = const {},
    this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory TapestryContent.fromJson(Map<String, dynamic> json) {
    return TapestryContent(
      id: json['id']?.toString(),
      profileId: json['profileId'] as String?,
      contentType: json['contentType'] as String?,
      text: json['text'] as String?,
      properties: json['properties'] as Map<String, dynamic>? ?? {},
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      likeCount: json['likeCount'] ?? json['likes'] ?? 0,
      commentCount: json['commentCount'] ?? json['comments'] ?? 0,
    );
  }
}

/// Tapestry comment model
class TapestryComment {
  final String? id;
  final String? profileId;
  final String? contentId;
  final String? text;
  final DateTime? createdAt;

  TapestryComment({
    this.id,
    this.profileId,
    this.contentId,
    this.text,
    this.createdAt,
  });

  factory TapestryComment.fromJson(Map<String, dynamic> json) {
    return TapestryComment(
      id: json['id']?.toString(),
      profileId: json['profileId'] as String?,
      contentId: json['contentId'] as String?,
      text: json['text'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
}
