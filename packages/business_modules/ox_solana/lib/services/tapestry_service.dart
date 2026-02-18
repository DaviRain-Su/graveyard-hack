import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tapestry identity service — links Nostr pubkey ↔ Solana address.
///
/// Architecture: **Local-first with optional Tapestry API sync**
/// - Local cache always works (SharedPreferences) — stores Nostr→Solana mappings
/// - Tapestry API (https://api.usetapestry.dev) used when API key is available
/// - Without API key: purely local P2P address book (still fully functional)
/// - With API key: syncs to on-chain social graph for discoverability
class TapestryService {
  static final TapestryService instance = TapestryService._();
  TapestryService._();

  static const String _baseUrl = 'https://api.usetapestry.dev/api/v1';
  static const String _storageKey = 'ox_solana_tapestry_profile';
  static const String _localBindingsKey = 'ox_solana_local_bindings';
  static const String _apiKeyStorageKey = 'ox_solana_tapestry_api_key';

  String? _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  String? _profileId;
  String? get profileId => _profileId;
  bool get hasBoundProfile => _profileId != null || _localBindings.isNotEmpty;

  TapestryProfile? _profile;
  TapestryProfile? get profile => _profile;

  // Local Nostr pubkey → Solana address cache
  Map<String, String> _localBindings = {};
  Map<String, String> get localBindings => Map.unmodifiable(_localBindings);

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

    // Load Tapestry profile ID
    _profileId = prefs.getString(_storageKey);
    if (_profileId != null && hasApiKey) {
      await fetchProfile();
    }

    if (kDebugMode) {
      print('[Tapestry] Init: ${_localBindings.length} local bindings, API key: ${hasApiKey ? "yes" : "no"}');
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
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey != null) 'x-api-key': _apiKey!,
  };

  // ===================== LOCAL BINDING (always works) =====================

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

    // 2. Try Tapestry API if available
    if (hasApiKey) {
      try {
        final profile = await findByNostrPubkey(nostrPubkey);
        if (profile != null && profile.wallets.isNotEmpty) {
          final solWallet = profile.wallets.firstWhere(
            (w) => w.blockchain == 'solana',
            orElse: () => profile.wallets.first,
          );
          // Cache it locally for future lookups
          await bindLocal(nostrPubkey: nostrPubkey, solanaAddress: solWallet.address);
          return solWallet.address;
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

  /// Get display name for a Nostr pubkey (for showing in UI)
  String? getDisplayName(String nostrPubkey) {
    return _profile?.username;
  }

  /// Get all known contacts with Solana wallets
  List<MapEntry<String, String>> get knownSolanaContacts =>
      _localBindings.entries.toList();

  Future<void> _saveLocalBindings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localBindingsKey, jsonEncode(_localBindings));
  }

  // ===================== TAPESTRY API (needs API key) =====================

  /// Create a Tapestry profile linking Nostr + Solana (requires API key)
  Future<TapestryProfile?> createProfile({
    required String nostrPubkey,
    required String solanaAddress,
    String? displayName,
  }) async {
    // Always save locally first
    await bindLocal(nostrPubkey: nostrPubkey, solanaAddress: solanaAddress);

    if (!hasApiKey) {
      if (kDebugMode) print('[Tapestry] No API key — saved locally only');
      // Return a local-only profile
      _profile = TapestryProfile(
        id: 'local_${nostrPubkey.substring(0, 8)}',
        username: displayName ?? 'nostr_${nostrPubkey.substring(0, 8)}',
        bio: 'Nostr + Solana identity (local)',
        wallets: [TapestryWallet(address: solanaAddress, blockchain: 'solana')],
        properties: {'nostr_pubkey': nostrPubkey},
        isLocal: true,
      );
      return _profile;
    }

    try {
      final body = {
        'username': displayName ?? 'nostr_${nostrPubkey.substring(0, 8)}',
        'bio': 'Nostr + Solana identity',
        'wallets': [
          {
            'address': solanaAddress,
            'blockchain': 'solana',
            'label': 'primary',
          },
        ],
        'properties': {
          'nostr_pubkey': nostrPubkey,
          'platform': '0xchat',
          'created_at': DateTime.now().toIso8601String(),
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/profiles'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('[Tapestry] Create profile: ${response.statusCode}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _profileId = data['id']?.toString() ?? data['profile_id']?.toString();
        _profile = TapestryProfile.fromJson(data);

        final prefs = await SharedPreferences.getInstance();
        if (_profileId != null) {
          await prefs.setString(_storageKey, _profileId!);
        }
        return _profile;
      } else {
        if (kDebugMode) {
          print('[Tapestry] Create failed: ${response.statusCode} ${response.body}');
        }
        // API failed but local binding still works
        return _profile;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Create error: $e');
      return _profile; // return local profile
    }
  }

  /// Fetch existing profile from Tapestry API
  Future<TapestryProfile?> fetchProfile() async {
    if (_profileId == null || !hasApiKey) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profiles/$_profileId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _profile = TapestryProfile.fromJson(data);
        return _profile;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Fetch error: $e');
    }
    return null;
  }

  /// Search for a profile by Solana address via Tapestry API
  Future<TapestryProfile?> findByWallet(String solanaAddress) async {
    if (!hasApiKey) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profiles/wallet/$solanaAddress'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TapestryProfile.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Find by wallet error: $e');
    }
    return null;
  }

  /// Search for a profile by Nostr pubkey via Tapestry API
  Future<TapestryProfile?> findByNostrPubkey(String nostrPubkey) async {
    if (!hasApiKey) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profiles?nostr_pubkey=$nostrPubkey'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return TapestryProfile.fromJson(data.first);
        }
        if (data is Map && data.containsKey('profiles')) {
          final profiles = data['profiles'] as List;
          if (profiles.isNotEmpty) {
            return TapestryProfile.fromJson(profiles.first);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Find by Nostr error: $e');
    }
    return null;
  }

  /// Clear all saved data
  Future<void> clearBinding() async {
    _profileId = null;
    _profile = null;
    _localBindings.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_localBindingsKey);
  }
}

/// Tapestry profile model
class TapestryProfile {
  final String? id;
  final String? username;
  final String? bio;
  final List<TapestryWallet> wallets;
  final Map<String, dynamic> properties;
  final bool isLocal; // true = local only, not synced to Tapestry

  TapestryProfile({
    this.id,
    this.username,
    this.bio,
    this.wallets = const [],
    this.properties = const {},
    this.isLocal = false,
  });

  String? get nostrPubkey => properties['nostr_pubkey'] as String?;

  factory TapestryProfile.fromJson(Map<String, dynamic> json) {
    final walletsData = json['wallets'] as List? ?? [];
    return TapestryProfile(
      id: json['id']?.toString() ?? json['profile_id']?.toString(),
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      wallets: walletsData.map((w) => TapestryWallet.fromJson(w as Map<String, dynamic>)).toList(),
      properties: json['properties'] as Map<String, dynamic>? ?? {},
      isLocal: false,
    );
  }
}

/// Tapestry wallet entry
class TapestryWallet {
  final String address;
  final String blockchain;
  final String? label;

  TapestryWallet({
    required this.address,
    required this.blockchain,
    this.label,
  });

  factory TapestryWallet.fromJson(Map<String, dynamic> json) {
    return TapestryWallet(
      address: json['address'] as String? ?? '',
      blockchain: json['blockchain'] as String? ?? 'solana',
      label: json['label'] as String?,
    );
  }
}
