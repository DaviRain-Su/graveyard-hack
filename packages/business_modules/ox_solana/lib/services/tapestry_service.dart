import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tapestry Deep Integration — On-chain Social Graph for 0xchat
///
/// Base URL: https://api.usetapestry.dev/api/v1
/// Auth: ?apiKey=xxx (query param)
///
/// All endpoints verified against real API + socialfi npm SDK source.
/// Uses state compression + Merkle trees on Solana (same tech as cNFTs).
///
/// Verified API Map:
///   Profiles: findOrCreate, GET/{id}, PUT/{id}, search/profiles
///   Follows:  followers/add, followers/remove, followers/state, profiles/{id}/followers, profiles/{id}/following
///   Content:  contents/findOrCreate, GET/PUT/DELETE contents/{id}
///   Likes:    POST/DELETE likes/{nodeId} (body: {startId})
///   Comments: POST/GET comments, GET/PUT/DELETE comments/{id}
///   Wallets:  wallets/{address}/socialCounts
///   Activity: activity/feed
class TapestryService extends ChangeNotifier {
  static final TapestryService instance = TapestryService._();
  TapestryService._();

  // ──────── REAL verified base URL ────────
  static const String _baseUrl = 'https://api.usetapestry.dev/api/v1';

  static const String _storageKey = 'ox_solana_tapestry_profile';
  static const String _localBindingsKey = 'ox_solana_local_bindings';
  static const String _apiKeyStorageKey = 'ox_solana_tapestry_api_key';
  static const String _followCacheKey = 'ox_solana_tapestry_follows';
  static const String _contentIdsKey = 'ox_solana_tapestry_content_ids';

  String? _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  String? _profileId;
  String? get profileId => _profileId;

  TapestryProfile? _profile;
  TapestryProfile? get profile => _profile;

  int _followersCount = 0;
  int _followingCount = 0;
  int get followersCount => _followersCount;
  int get followingCount => _followingCount;

  Map<String, String> _localBindings = {};
  Map<String, String> get localBindings => Map.unmodifiable(_localBindings);

  Set<String> _followingCache = {};
  bool isFollowingCached(String profileId) => _followingCache.contains(profileId);

  /// Local cache of content IDs we created (for feed reconstruction)
  List<String> _myContentIds = [];
  List<String> get myContentIds => List.unmodifiable(_myContentIds);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get hasBoundProfile => _profileId != null || _localBindings.isNotEmpty;

  // ═══════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════

  Future<void> init({String? apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = apiKey ?? prefs.getString(_apiKeyStorageKey);

    final bindingsJson = prefs.getString(_localBindingsKey);
    if (bindingsJson != null) {
      try {
        _localBindings = Map<String, String>.from(jsonDecode(bindingsJson));
      } catch (_) {
        _localBindings = {};
      }
    }

    final followJson = prefs.getString(_followCacheKey);
    if (followJson != null) {
      try {
        _followingCache = Set<String>.from(jsonDecode(followJson));
      } catch (_) {
        _followingCache = {};
      }
    }

    final contentIdsJson = prefs.getString(_contentIdsKey);
    if (contentIdsJson != null) {
      try {
        _myContentIds = List<String>.from(jsonDecode(contentIdsJson));
      } catch (_) {
        _myContentIds = [];
      }
    }

    _profileId = prefs.getString(_storageKey);
    if (_profileId != null && hasApiKey) {
      await fetchProfile();
    }

    if (kDebugMode) {
      print('[Tapestry] Init: ${_localBindings.length} bindings, ${_followingCache.length} follows, API: ${hasApiKey}');
    }
  }

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

  // ── HTTP helpers ──

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  String _url(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return '$_baseUrl$path${separator}apiKey=$_apiKey';
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    if (!hasApiKey) return null;
    try {
      final r = await http.get(Uri.parse(_url(path)), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) return jsonDecode(r.body);
      if (kDebugMode) print('[Tapestry] GET $path → ${r.statusCode}: ${r.body.substring(0, (r.body.length).clamp(0, 200))}');
    } catch (e) {
      if (kDebugMode) print('[Tapestry] GET $path error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    if (!hasApiKey) return null;
    try {
      final r = await http.post(Uri.parse(_url(path)), headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 || r.statusCode == 201) {
        return r.body.isNotEmpty ? jsonDecode(r.body) : {};
      }
      if (kDebugMode) print('[Tapestry] POST $path → ${r.statusCode}: ${r.body.substring(0, (r.body.length).clamp(0, 200))}');
    } catch (e) {
      if (kDebugMode) print('[Tapestry] POST $path error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _put(String path, Map<String, dynamic> body) async {
    if (!hasApiKey) return null;
    try {
      final r = await http.put(Uri.parse(_url(path)), headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) return jsonDecode(r.body);
      if (kDebugMode) print('[Tapestry] PUT $path → ${r.statusCode}');
    } catch (e) {
      if (kDebugMode) print('[Tapestry] PUT $path error: $e');
    }
    return null;
  }

  Future<bool> _delete(String path, [Map<String, dynamic>? body]) async {
    if (!hasApiKey) return false;
    try {
      final request = http.Request('DELETE', Uri.parse(_url(path)));
      request.headers.addAll(_jsonHeaders);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await request.send().timeout(const Duration(seconds: 12));
      return streamed.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('[Tapestry] DELETE $path error: $e');
    }
    return false;
  }

  // ═══════════════════════════════════════════
  // 1. PROFILES
  //    POST /profiles/findOrCreate
  //    GET  /profiles/{id}
  //    PUT  /profiles/{id}
  //    GET  /search/profiles?query=
  //    GET  /profiles/suggested/{id}
  // ═══════════════════════════════════════════

  /// Create or find profile (Tapestry official pattern)
  /// properties/customProperties use [{key,value}] array format
  Future<TapestryProfile?> findOrCreateProfile({
    required String walletAddress,
    required String username,
    String? id,
    String? bio,
    String? image,
    String? nostrPubkey,
    Map<String, String>? customProperties,
  }) async {
    // Always save locally first
    if (nostrPubkey != null) {
      await bindLocal(nostrPubkey: nostrPubkey, solanaAddress: walletAddress);
    }

    if (!hasApiKey) {
      _profile = TapestryProfile(
        id: username,
        username: username,
        bio: bio,
        walletAddress: walletAddress,
        isLocal: true,
        customProperties: {
          if (nostrPubkey != null) 'nostr_pubkey': nostrPubkey,
          'platform': '0xchat',
        },
      );
      _profileId = username;
      notifyListeners();
      return _profile;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final props = <Map<String, String>>[
        if (nostrPubkey != null) {'key': 'nostr_pubkey', 'value': nostrPubkey},
        {'key': 'platform', 'value': '0xchat'},
        {'key': 'created_at', 'value': DateTime.now().toIso8601String()},
        if (customProperties != null)
          ...customProperties.entries.map((e) => {'key': e.key, 'value': e.value}),
      ];

      final data = await _post('/profiles/findOrCreate', {
        'walletAddress': walletAddress,
        'username': username,
        if (id != null) 'id': id,
        if (bio != null) 'bio': bio,
        if (image != null) 'image': image,
        'blockchain': 'SOLANA',
        'execution': 'FAST_UNCONFIRMED',
        if (props.isNotEmpty) 'customProperties': props,
      });

      if (data != null) {
        final profileData = data['profile'] as Map<String, dynamic>? ?? data;
        _profile = TapestryProfile.fromApi(profileData);
        _profileId = _profile!.id ?? username;

        // operation: CREATED or FOUND
        if (kDebugMode) print('[Tapestry] findOrCreate: ${data['operation']}');

        final counts = data['socialCounts'] as Map<String, dynamic>? ?? {};
        _followersCount = counts['followers'] ?? 0;
        _followingCount = counts['following'] ?? 0;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, _profileId!);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _profile;
  }

  /// GET /profiles/{id}
  Future<TapestryProfile?> fetchProfile([String? id]) async {
    final pid = id ?? _profileId;
    if (pid == null) return null;

    final data = await _get('/profiles/$pid');
    if (data == null) return null;

    final profileData = data['profile'] as Map<String, dynamic>? ?? data;
    final profile = TapestryProfile.fromApi(profileData);

    if (id == null || id == _profileId) {
      _profile = profile;
      _profile = profile.copyWith(
        walletAddress: data['walletAddress'] as String?,
      );
      final counts = data['socialCounts'] as Map<String, dynamic>? ?? {};
      _followersCount = counts['followers'] ?? 0;
      _followingCount = counts['following'] ?? 0;
      notifyListeners();
    }
    return profile;
  }

  /// PUT /profiles/{id}
  Future<TapestryProfile?> updateProfile({
    String? username,
    String? bio,
    String? image,
    Map<String, String>? properties,
  }) async {
    if (_profileId == null) return null;

    final body = <String, dynamic>{
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
      if (image != null) 'image': image,
      'execution': 'FAST_UNCONFIRMED',
      if (properties != null)
        'properties': properties.entries.map((e) => {'key': e.key, 'value': e.value}).toList(),
    };

    final data = await _put('/profiles/$_profileId', body);
    if (data != null) {
      _profile = TapestryProfile.fromApi(data);
      notifyListeners();
      return _profile;
    }
    return null;
  }

  /// GET /search/profiles?query=
  Future<List<TapestryProfile>> searchProfiles(String query, {int page = 1, int pageSize = 10}) async {
    final data = await _get('/search/profiles?query=${Uri.encodeComponent(query)}&page=$page&pageSize=$pageSize');
    if (data == null) return [];

    final profiles = data['profiles'] as List? ?? [];
    return profiles.map<TapestryProfile>((p) {
      final pd = p['profile'] as Map<String, dynamic>? ?? p as Map<String, dynamic>;
      final profile = TapestryProfile.fromApi(pd);
      // Attach social counts + wallet from search result
      return profile.copyWith(
        walletAddress: p['walletAddress'] as String?,
        followersCount: (p['socialCounts'] as Map?)?['followers'],
        followingCount: (p['socialCounts'] as Map?)?['following'],
        namespaceName: (p['namespace'] as Map?)?['readableName'] as String?,
      );
    }).toList();
  }

  /// GET /profiles/suggested/{id}
  Future<List<TapestryProfile>> getSuggestedProfiles() async {
    if (_profileId == null) return [];
    final data = await _get('/profiles/suggested/$_profileId');
    if (data == null) return [];

    final profiles = data['profiles'] as List? ?? [];
    return profiles.map<TapestryProfile>((p) =>
      TapestryProfile.fromApi(p as Map<String, dynamic>)
    ).toList();
  }

  // ═══════════════════════════════════════════
  // 2. FOLLOWS
  //    POST /followers/add     (body: {startId, endId})
  //    POST /followers/remove  (body: {startId, endId})
  //    GET  /followers/state   (?startId=&endId=)
  //    GET  /profiles/{id}/followers
  //    GET  /profiles/{id}/following
  // ═══════════════════════════════════════════

  /// POST /followers/add
  Future<bool> followUser(String targetId) async {
    if (_profileId == null) return false;

    final data = await _post('/followers/add', {
      'startId': _profileId,
      'endId': targetId,
    });

    if (data != null) {
      _followingCache.add(targetId);
      _followingCount++;
      await _saveFollowCache();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// POST /followers/remove
  Future<bool> unfollowUser(String targetId) async {
    if (_profileId == null) return false;

    final data = await _post('/followers/remove', {
      'startId': _profileId,
      'endId': targetId,
    });

    if (data != null) {
      _followingCache.remove(targetId);
      _followingCount = (_followingCount - 1).clamp(0, 999999);
      await _saveFollowCache();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// GET /followers/state?startId=&endId=
  Future<bool> isFollowing(String targetId) async {
    if (_followingCache.contains(targetId)) return true;
    if (_profileId == null) return false;

    final data = await _get('/followers/state?startId=$_profileId&endId=$targetId');
    if (data != null) {
      final following = data['isFollowing'] == true;
      if (following) {
        _followingCache.add(targetId);
        await _saveFollowCache();
      }
      return following;
    }
    return false;
  }

  /// GET /profiles/{id}/followers
  Future<TapestryPaginatedProfiles> getFollowers({String? id, int page = 1, int pageSize = 20}) async {
    final pid = id ?? _profileId;
    if (pid == null) return TapestryPaginatedProfiles.empty();

    final data = await _get('/profiles/$pid/followers?page=$page&pageSize=$pageSize');
    return TapestryPaginatedProfiles.fromApi(data);
  }

  /// GET /profiles/{id}/following
  Future<TapestryPaginatedProfiles> getFollowing({String? id, int page = 1, int pageSize = 20}) async {
    final pid = id ?? _profileId;
    if (pid == null) return TapestryPaginatedProfiles.empty();

    final data = await _get('/profiles/$pid/following?page=$page&pageSize=$pageSize');
    return TapestryPaginatedProfiles.fromApi(data);
  }

  /// Refresh follower/following counts from profile
  Future<void> refreshSocialCounts() async {
    if (_profileId == null) return;
    await fetchProfile();
  }

  // ═══════════════════════════════════════════
  // 3. CONTENT
  //    POST /contents/findOrCreate (id, profileId, properties[{key,value}])
  //    GET  /contents/{id}
  //    PUT  /contents/{id}
  //    DELETE /contents/{id}
  // ═══════════════════════════════════════════

  /// POST /contents/findOrCreate
  /// properties use [{key, value}] array format
  Future<TapestryContent?> createContent({
    required String contentId,
    required String text,
    String contentType = 'text_post',
    Map<String, String>? metadata,
  }) async {
    if (_profileId == null) return null;

    final props = <Map<String, String>>[
      {'key': 'contentType', 'value': contentType},
      {'key': 'text', 'value': text},
      {'key': 'platform', 'value': '0xchat'},
      {'key': 'created_at', 'value': DateTime.now().toIso8601String()},
      if (metadata != null)
        ...metadata.entries.map((e) => {'key': e.key, 'value': e.value}),
    ];

    final data = await _post('/contents/findOrCreate', {
      'id': contentId,
      'profileId': _profileId,
      'properties': props,
    });

    if (data != null) {
      // Cache content ID locally for feed reconstruction
      if (!_myContentIds.contains(contentId)) {
        _myContentIds.insert(0, contentId);
        // Keep max 100
        if (_myContentIds.length > 100) _myContentIds = _myContentIds.sublist(0, 100);
        _saveContentIds();
      }
      return TapestryContent.fromApi(data);
    }
    return null;
  }

  /// GET /contents/{id} — returns content + socialCounts + authorProfile
  Future<TapestryContent?> getContent(String contentId) async {
    final data = await _get('/contents/$contentId');
    if (data == null) return null;
    return TapestryContent.fromDetailApi(data);
  }

  /// DELETE /contents/{id}
  Future<bool> deleteContent(String contentId) async {
    final ok = await _delete('/contents/$contentId');
    if (ok) {
      _myContentIds.remove(contentId);
      _saveContentIds();
    }
    return ok;
  }

  /// Load my feed by fetching cached content IDs from API
  /// Returns latest [limit] items, fetched in parallel
  Future<List<TapestryContent>> getMyFeed({int limit = 20}) async {
    if (_myContentIds.isEmpty) return [];

    final ids = _myContentIds.take(limit).toList();
    final results = <TapestryContent>[];

    // Fetch in parallel batches of 5
    for (var i = 0; i < ids.length; i += 5) {
      final batch = ids.sublist(i, (i + 5).clamp(0, ids.length));
      final futures = batch.map((id) => getContent(id));
      final contents = await Future.wait(futures);
      for (final c in contents) {
        if (c != null) results.add(c);
      }
    }
    return results;
  }

  Future<void> _saveContentIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contentIdsKey, jsonEncode(_myContentIds));
  }

  // ═══════════════════════════════════════════
  // 4. LIKES
  //    POST   /likes/{nodeId}  (body: {startId})
  //    DELETE  /likes/{nodeId}  (body: {startId})
  // ═══════════════════════════════════════════

  /// POST /likes/{nodeId}
  Future<bool> likeContent(String nodeId) async {
    if (_profileId == null) return false;
    final data = await _post('/likes/$nodeId', {'startId': _profileId!});
    return data != null;
  }

  /// DELETE /likes/{nodeId}
  Future<bool> unlikeContent(String nodeId) async {
    if (_profileId == null) return false;
    return await _delete('/likes/$nodeId', {'startId': _profileId!});
  }

  // ═══════════════════════════════════════════
  // 5. COMMENTS
  //    POST /comments         (contentId, profileId, text)
  //    GET  /comments?contentId=
  //    DELETE /comments/{id}
  // ═══════════════════════════════════════════

  /// POST /comments
  Future<TapestryComment?> addComment({
    required String contentId,
    required String text,
  }) async {
    if (_profileId == null) return null;

    final data = await _post('/comments', {
      'contentId': contentId,
      'profileId': _profileId,
      'text': text,
    });

    if (data != null) {
      return TapestryComment.fromApi(data);
    }
    return null;
  }

  /// GET /comments?contentId=
  Future<List<TapestryComment>> getComments(String contentId, {int page = 1, int pageSize = 20}) async {
    final data = await _get('/comments?contentId=$contentId&page=$page&pageSize=$pageSize');
    if (data == null) return [];

    final comments = data['comments'] as List? ?? [];
    return comments.map<TapestryComment>((c) => TapestryComment.fromDetailApi(c as Map<String, dynamic>)).toList();
  }

  /// DELETE /comments/{id}
  Future<bool> deleteComment(String commentId) async {
    return await _delete('/comments/$commentId');
  }

  // ═══════════════════════════════════════════
  // 6. WALLETS
  //    GET /wallets/{address}/socialCounts
  // ═══════════════════════════════════════════

  /// GET /wallets/{address}/socialCounts
  Future<Map<String, int>> getWalletSocialCounts(String walletAddress) async {
    final data = await _get('/wallets/$walletAddress/socialCounts');
    if (data == null) return {};
    return {
      'followers': data['followers'] ?? 0,
      'following': data['following'] ?? 0,
      'globalFollowers': data['globalFollowers'] ?? 0,
      'globalFollowing': data['globalFollowing'] ?? 0,
    };
  }

  // ═══════════════════════════════════════════
  // CONVENIENCE: Auto-share from wallet actions
  // ═══════════════════════════════════════════

  /// Share a transaction to social feed
  Future<void> shareTransaction({
    required String signature,
    required double amount,
    required String tokenSymbol,
    required String toAddress,
    bool isDevnet = false,
  }) async {
    final id = 'tx_${signature.substring(0, 16)}_${DateTime.now().millisecondsSinceEpoch}';
    await createContent(
      contentId: id,
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

  /// Share an NFT to social feed
  Future<void> shareNft({required String nftName, required String mintAddress, String? imageUrl}) async {
    final id = 'nft_${mintAddress.substring(0, 12)}_${DateTime.now().millisecondsSinceEpoch}';
    await createContent(
      contentId: id,
      contentType: 'nft_share',
      text: 'Check out my NFT: $nftName 🖼️',
      metadata: {
        'nft_name': nftName,
        'mint_address': mintAddress,
        if (imageUrl != null) 'image_url': imageUrl,
      },
    );
  }

  /// Share music to social feed
  Future<void> shareMusicToFeed({required String title, required String artist, required String trackId}) async {
    final id = 'music_${trackId}_${DateTime.now().millisecondsSinceEpoch}';
    await createContent(
      contentId: id,
      contentType: 'music_share',
      text: '🎵 Listening to "$title" by $artist on Audius',
      metadata: {
        'track_title': title,
        'artist': artist,
        'audius_track_id': trackId,
      },
    );
  }

  // ═══════════════════════════════════════════
  // LOCAL BINDING (always works without API key)
  // ═══════════════════════════════════════════

  Future<void> bindLocal({required String nostrPubkey, required String solanaAddress}) async {
    _localBindings[nostrPubkey] = solanaAddress;
    await _saveLocalBindings();
  }

  Future<void> unbindLocal(String nostrPubkey) async {
    _localBindings.remove(nostrPubkey);
    await _saveLocalBindings();
  }

  Future<String?> resolveNostrToSolana(String nostrPubkey) async {
    final local = _localBindings[nostrPubkey];
    if (local != null) return local;

    if (hasApiKey) {
      final results = await searchProfiles(nostrPubkey);
      for (final p in results) {
        if (p.customProperties['nostr_pubkey'] == nostrPubkey && p.walletAddress != null) {
          await bindLocal(nostrPubkey: nostrPubkey, solanaAddress: p.walletAddress!);
          return p.walletAddress;
        }
      }
    }
    return null;
  }

  String? resolveSolanaToNostr(String solanaAddress) {
    for (final entry in _localBindings.entries) {
      if (entry.value == solanaAddress) return entry.key;
    }
    return null;
  }

  List<MapEntry<String, String>> get knownSolanaContacts => _localBindings.entries.toList();

  // ═══════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════

  Future<void> clearBinding() async {
    _profileId = null;
    _profile = null;
    _followersCount = 0;
    _followingCount = 0;
    _localBindings.clear();
    _followingCache.clear();
    _myContentIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_localBindingsKey);
    await prefs.remove(_followCacheKey);
    await prefs.remove(_contentIdsKey);
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
// MODELS — Matching real Tapestry API response format
// ═══════════════════════════════════════════════════════

class TapestryProfile {
  final String? id;
  final String? username;
  final String? bio;
  final String? image;
  final String? walletAddress;
  final String? namespace;
  final String? namespaceName;
  final int? createdAt;
  final Map<String, dynamic> customProperties;
  final bool isLocal;
  final int? followersCount;
  final int? followingCount;

  TapestryProfile({
    this.id, this.username, this.bio, this.image, this.walletAddress,
    this.namespace, this.namespaceName, this.createdAt,
    this.customProperties = const {}, this.isLocal = false,
    this.followersCount, this.followingCount,
  });

  String? get nostrPubkey => customProperties['nostr_pubkey'] as String?;
  String? get platform => customProperties['platform'] as String?;

  TapestryProfile copyWith({
    String? walletAddress, String? namespaceName,
    int? followersCount, int? followingCount,
  }) => TapestryProfile(
    id: id, username: username, bio: bio, image: image,
    walletAddress: walletAddress ?? this.walletAddress,
    namespace: namespace,
    namespaceName: namespaceName ?? this.namespaceName,
    createdAt: createdAt,
    customProperties: customProperties,
    isLocal: isLocal,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount ?? this.followingCount,
  );

  /// Parse from real API response (profile node is flat)
  /// Fields: id, username, bio, image, namespace, created_at, + custom properties flattened
  factory TapestryProfile.fromApi(Map<String, dynamic> json) {
    // Known system fields
    const systemKeys = {'id', 'username', 'bio', 'image', 'namespace', 'created_at', 'walletAddress', 'blockchain', 'wallet'};
    final custom = <String, dynamic>{};
    for (final e in json.entries) {
      if (!systemKeys.contains(e.key) && e.value != null) {
        custom[e.key] = e.value;
      }
    }

    // Wallet can come from nested 'wallet' object
    String? walletAddr = json['walletAddress'] as String?;
    if (walletAddr == null && json['wallet'] is Map) {
      walletAddr = (json['wallet'] as Map)['id'] as String?;
    }

    return TapestryProfile(
      id: json['id']?.toString(),
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      image: json['image'] as String?,
      walletAddress: walletAddr,
      namespace: json['namespace'] as String?,
      createdAt: json['created_at'] as int?,
      customProperties: custom,
    );
  }
}

class TapestryPaginatedProfiles {
  final List<TapestryProfile> profiles;
  final int page;
  final int pageSize;
  final int totalCount;

  TapestryPaginatedProfiles({this.profiles = const [], this.page = 1, this.pageSize = 10, this.totalCount = 0});

  factory TapestryPaginatedProfiles.empty() => TapestryPaginatedProfiles();

  factory TapestryPaginatedProfiles.fromApi(Map<String, dynamic>? data) {
    if (data == null) return TapestryPaginatedProfiles.empty();
    final list = data['profiles'] as List? ?? [];
    return TapestryPaginatedProfiles(
      profiles: list.map<TapestryProfile>((p) => TapestryProfile.fromApi(p as Map<String, dynamic>)).toList(),
      page: data['page'] ?? 1,
      pageSize: data['pageSize'] ?? 10,
      totalCount: data['totalCount'] ?? 0,
    );
  }
}

class TapestryContent {
  final String? id;
  final String? namespace;
  final int? createdAt;
  final String? text;
  final String? contentType;
  final Map<String, dynamic> properties;
  // From detail view
  final int likeCount;
  final int commentCount;
  final TapestryProfile? author;

  TapestryContent({
    this.id, this.namespace, this.createdAt, this.text, this.contentType,
    this.properties = const {},
    this.likeCount = 0, this.commentCount = 0, this.author,
  });

  /// Parse from findOrCreate response (flat properties)
  factory TapestryContent.fromApi(Map<String, dynamic> json) {
    return TapestryContent(
      id: json['id']?.toString(),
      namespace: json['namespace'] as String?,
      createdAt: json['created_at'] as int?,
      text: json['text'] as String?,
      contentType: json['contentType'] as String?,
      properties: Map<String, dynamic>.from(json),
    );
  }

  /// Parse from GET /contents/{id} (nested: content, socialCounts, authorProfile)
  factory TapestryContent.fromDetailApi(Map<String, dynamic> json) {
    final c = json['content'] as Map<String, dynamic>? ?? json;
    final counts = json['socialCounts'] as Map<String, dynamic>? ?? {};
    final authorData = json['authorProfile'] as Map<String, dynamic>?;

    return TapestryContent(
      id: c['id']?.toString(),
      namespace: c['namespace'] as String?,
      createdAt: c['created_at'] as int?,
      text: c['text'] as String?,
      contentType: c['contentType'] as String?,
      properties: Map<String, dynamic>.from(c),
      likeCount: counts['likeCount'] ?? 0,
      commentCount: counts['commentCount'] ?? 0,
      author: authorData != null ? TapestryProfile.fromApi(authorData) : null,
    );
  }
}

class TapestryComment {
  final String? id;
  final String? text;
  final int? createdAt;
  final TapestryProfile? author;
  final int likeCount;

  TapestryComment({this.id, this.text, this.createdAt, this.author, this.likeCount = 0});

  /// Parse from POST /comments response (flat)
  factory TapestryComment.fromApi(Map<String, dynamic> json) {
    return TapestryComment(
      id: json['id']?.toString(),
      text: json['text'] as String?,
      createdAt: json['created_at'] as int?,
    );
  }

  /// Parse from GET /comments (nested: comment, author, socialCounts)
  factory TapestryComment.fromDetailApi(Map<String, dynamic> json) {
    final c = json['comment'] as Map<String, dynamic>? ?? json;
    final authorData = json['author'] as Map<String, dynamic>?;
    final counts = json['socialCounts'] as Map<String, dynamic>? ?? {};

    return TapestryComment(
      id: c['id']?.toString(),
      text: c['text'] as String?,
      createdAt: c['created_at'] as int?,
      author: authorData != null ? TapestryProfile.fromApi(authorData) : null,
      likeCount: counts['likeCount'] ?? 0,
    );
  }
}
