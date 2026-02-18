import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tapestry identity service — links Nostr pubkey ↔ Solana address on-chain.
/// API docs: https://api.usetapestry.dev/docs
class TapestryService {
  static final TapestryService instance = TapestryService._();
  TapestryService._();

  static const String _baseUrl = 'https://api.usetapestry.dev/api/v1';
  static const String _storageKey = 'ox_solana_tapestry_profile';

  // Set your Tapestry API key here or via env
  String? _apiKey;

  String? _profileId;
  String? get profileId => _profileId;
  bool get hasBoundProfile => _profileId != null;

  TapestryProfile? _profile;
  TapestryProfile? get profile => _profile;

  /// Initialize — load saved profile ID
  Future<void> init({String? apiKey}) async {
    _apiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    _profileId = prefs.getString(_storageKey);
    if (_profileId != null) {
      await fetchProfile();
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey != null) 'x-api-key': _apiKey!,
  };

  /// Create a new Tapestry profile linking Nostr + Solana
  Future<TapestryProfile?> createProfile({
    required String nostrPubkey,
    required String solanaAddress,
    String? displayName,
  }) async {
    try {
      // Create profile with Nostr identity as the base
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
      );

      if (kDebugMode) {
        print('[Tapestry] Create profile: ${response.statusCode} ${response.body.substring(0, 200.clamp(0, response.body.length))}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _profileId = data['id']?.toString() ?? data['profile_id']?.toString();
        _profile = TapestryProfile.fromJson(data);

        // Save profile ID
        final prefs = await SharedPreferences.getInstance();
        if (_profileId != null) {
          await prefs.setString(_storageKey, _profileId!);
        }

        return _profile;
      } else {
        if (kDebugMode) {
          print('[Tapestry] Create failed: ${response.statusCode} ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Create error: $e');
      return null;
    }
  }

  /// Fetch existing profile
  Future<TapestryProfile?> fetchProfile() async {
    if (_profileId == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profiles/$_profileId'),
        headers: _headers,
      );

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

  /// Search for a profile by Solana address
  Future<TapestryProfile?> findByWallet(String solanaAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profiles/wallet/$solanaAddress'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TapestryProfile.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) print('[Tapestry] Find by wallet error: $e');
    }
    return null;
  }

  /// Search for a profile by Nostr pubkey (via properties)
  Future<TapestryProfile?> findByNostrPubkey(String nostrPubkey) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profiles?nostr_pubkey=$nostrPubkey'),
        headers: _headers,
      );

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

  /// Resolve a Nostr pubkey to Solana address (for chat transfers)
  Future<String?> resolveNostrToSolana(String nostrPubkey) async {
    final profile = await findByNostrPubkey(nostrPubkey);
    if (profile != null && profile.wallets.isNotEmpty) {
      final solWallet = profile.wallets.firstWhere(
        (w) => w.blockchain == 'solana',
        orElse: () => profile.wallets.first,
      );
      return solWallet.address;
    }
    return null;
  }

  /// Clear saved profile binding
  Future<void> clearBinding() async {
    _profileId = null;
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

/// Tapestry profile model
class TapestryProfile {
  final String? id;
  final String? username;
  final String? bio;
  final List<TapestryWallet> wallets;
  final Map<String, dynamic> properties;

  TapestryProfile({
    this.id,
    this.username,
    this.bio,
    this.wallets = const [],
    this.properties = const {},
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
