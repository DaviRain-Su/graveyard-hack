import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Torque Protocol Integration — Solana's Onchain Growth Protocol
///
/// Torque enables incentive campaigns: protocols publish tasks (swap, stake,
/// NFT trade, etc.) and users earn token rewards for completing them.
///
/// API Base: https://api.torque.so
/// Auth: Wallet signature → Bearer token
///
/// Flow:
///   1. GET /identify → {payload: {statement, issuedAt, expirationTime}}
///   2. ed25519 signMessage(statement) → base64 signature
///   3. POST /login → {token, pubKey, isPublisher, ...}
///   4. All subsequent requests: Authorization: Bearer <token>
///
/// SDK source verified at @torque-labs/torque-ts-sdk@0.0.136
class TorqueService extends ChangeNotifier {
  static final TorqueService instance = TorqueService._();
  TorqueService._();

  static const String _baseUrl = 'https://api.torque.so';
  static const String _appUrl = 'https://app.torque.so';
  static const String _tokenKey = 'ox_solana_torque_token';
  static const String _userKey = 'ox_solana_torque_user';

  String? _token;
  TorqueUser? _user;
  bool _isLoading = false;

  bool get isLoggedIn => _token != null && _user != null;
  bool get isLoading => _isLoading;
  TorqueUser? get user => _user;
  String? get token => _token;

  // ══════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        _user = TorqueUser.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }

    // Validate existing session
    if (_token != null) {
      try {
        final me = await getCurrentUser();
        if (me == null) {
          await _clearSession();
        }
      } catch (_) {
        // Token might be expired, don't clear yet — API could be down
      }
    }

    if (kDebugMode) {
      print('[Torque] Init: logged_in=$isLoggedIn');
    }
  }

  // ── HTTP helpers ──

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final r = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) return jsonDecode(r.body);
      if (kDebugMode) print('[Torque] GET $path → ${r.statusCode}');
    } catch (e) {
      if (kDebugMode) print('[Torque] GET $path error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 || r.statusCode == 201) {
        return r.body.isNotEmpty ? jsonDecode(r.body) : {};
      }
      if (kDebugMode) print('[Torque] POST $path → ${r.statusCode}: ${r.body.substring(0, r.body.length.clamp(0, 200))}');
    } catch (e) {
      if (kDebugMode) print('[Torque] POST $path error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════
  // 1. AUTHENTICATION
  //    GET  /identify    → sign payload
  //    POST /login       → get token
  //    GET  /logout
  // ══════════════════════════════════════════════

  /// Step 1: Get login challenge payload from Torque
  /// Returns the statement string to sign
  Future<TorqueLoginPayload?> getLoginPayload() async {
    final data = await _get('/identify');
    if (data == null) return null;
    return TorqueLoginPayload.fromJson(data);
  }

  /// Step 2: Login with signed payload
  /// [publicKey] - wallet public key (base58)
  /// [signedMessage] - base64 encoded signature of the statement
  /// [statement] - the original statement that was signed
  Future<TorqueUser?> login({
    required String publicKey,
    required String signedMessage,
    required String statement,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'authType': 'basic',
        'pubKey': publicKey,
        'payload': {
          'input': statement,
          'output': signedMessage,
        },
      };

      final data = await _post('/login', body);
      if (data != null && data['token'] != null) {
        _user = TorqueUser.fromJson(data);
        _token = data['token'] as String;
        await _saveSession();
        notifyListeners();
        return _user;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  /// Login helper — complete flow using a sign function
  /// [publicKey] - base58 wallet pubkey
  /// [signMessage] - function that signs a UTF-8 message, returns raw bytes
  Future<TorqueUser?> loginWithSigner({
    required String publicKey,
    required Future<Uint8List> Function(Uint8List message) signMessage,
  }) async {
    final payload = await getLoginPayload();
    if (payload == null) return null;

    final messageBytes = Uint8List.fromList(utf8.encode(payload.statement));
    final signature = await signMessage(messageBytes);
    final signatureBase64 = base64Encode(signature);

    return login(
      publicKey: publicKey,
      signedMessage: signatureBase64,
      statement: payload.statement,
    );
  }

  /// Logout
  Future<void> logout() async {
    await _get('/logout');
    await _clearSession();
    notifyListeners();
  }

  /// Get current user (validate session)
  Future<TorqueUser?> getCurrentUser() async {
    final data = await _get('/users/me');
    if (data != null) {
      _user = TorqueUser.fromJson(data);
      return _user;
    }
    return null;
  }

  // ══════════════════════════════════════════════
  // 2. OFFERS & CAMPAIGNS
  //    GET  /offers/{pubkey}
  //    POST /journey/start
  //    GET  /users/journey
  // ══════════════════════════════════════════════

  /// Get available offers/campaigns for the user
  Future<List<TorqueCampaign>> getOffers({String? profileSlug}) async {
    if (_user == null) return [];

    String path = '/offers/${_user!.pubKey}';
    if (profileSlug != null) path += '?profile=${Uri.encodeComponent(profileSlug)}';

    final data = await _get(path);
    if (data == null) return [];

    final campaigns = data['campaigns'] as List? ?? data['offers'] as List? ?? data['data'] as List? ?? [];
    return campaigns.map<TorqueCampaign>((c) => TorqueCampaign.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Accept/start a campaign
  Future<TorqueJourney?> acceptCampaign(String campaignId, {String publisherHandle = 'torqueprotocol'}) async {
    final data = await _post('/journey/start', {
      'campaignId': campaignId,
      'publisherHandle': publisherHandle,
    });

    if (data != null) {
      return TorqueJourney.fromJson(data);
    }
    return null;
  }

  /// Get user's active journeys
  Future<List<TorqueJourney>> getJourneys() async {
    final data = await _get('/users/journey');
    if (data == null) return [];

    final journeys = data['journeys'] as List? ?? [];
    return journeys.map((j) => TorqueJourney.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Get a specific journey for a campaign
  Future<TorqueJourney?> getCampaignJourney(String campaignId) async {
    final data = await _get('/users/journey?campaignId=$campaignId');
    if (data == null) return null;

    final journeys = data['journeys'] as List? ?? [];
    if (journeys.isNotEmpty) {
      return TorqueJourney.fromJson(journeys.first as Map<String, dynamic>);
    }
    return null;
  }

  // ══════════════════════════════════════════════
  // 3. ACTIONS (Solana Action / transaction)
  //    POST /actions/{publisher}/{campaignId}
  //    POST /actions/callback
  // ══════════════════════════════════════════════

  /// Get the Solana action/transaction for a specific campaign step
  /// Returns a Solana VersionedTransaction that needs to be signed
  Future<TorqueAction?> getBountyStepAction({
    required String campaignId,
    required int actionIndex,
    String publisherHandle = 'torqueprotocol',
    Map<String, String>? data,
  }) async {
    if (_user == null) return null;

    final params = <String, String>{
      'index': actionIndex.toString(),
      if (data != null) ...data,
    };
    final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/actions/$publisherHandle/$campaignId?$queryString'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'account': _user!.pubKey}),
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final json = jsonDecode(r.body);
        return TorqueAction.fromJson(json);
      }
    } catch (e) {
      if (kDebugMode) print('[Torque] getBountyStepAction error: $e');
    }
    return null;
  }

  /// Confirm action signature after user signs the transaction
  Future<TorqueAction?> confirmActionSignature({
    required String campaignId,
    required int index,
    required String encodedSignature,
  }) async {
    if (_user == null) return null;

    final params = 'campaignId=$campaignId&index=$index';
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/actions/callback?$params'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account': _user!.pubKey,
          'signature': encodedSignature,
        }),
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        return TorqueAction.fromJson(jsonDecode(r.body));
      }
    } catch (e) {
      if (kDebugMode) print('[Torque] confirmActionSignature error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════
  // 4. PAYOUTS & LEADERBOARDS
  //    GET  /users/payout/{pubkey}
  //    GET  /leaderboards
  // ══════════════════════════════════════════════

  /// Get user payout history
  Future<List<TorquePayout>> getPayouts() async {
    if (_user == null) return [];
    final data = await _get('/users/payout/${_user!.pubKey}');
    if (data == null) return [];

    final payouts = data['payouts'] as List? ?? [];
    return payouts.map((p) => TorquePayout.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Get leaderboards
  Future<Map<String, dynamic>?> getLeaderboards() async {
    return await _get('/leaderboards');
  }

  // ══════════════════════════════════════════════
  // 5. SHARE LINKS (Publisher)
  //    GET /share?campaignId=&handle=
  //    GET /links
  // ══════════════════════════════════════════════

  /// Generate a share link for a campaign
  String getShareLink(String campaignId) {
    final handle = _user?.username ?? _user?.publisherPubKey ?? _user?.pubKey;
    return '$_appUrl/share/$handle/$campaignId';
  }

  /// Get all user share links
  Future<List<Map<String, dynamic>>> getAllShareLinks() async {
    final data = await _get('/links');
    if (data == null) return [];
    return (data['links'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════
  // SESSION PERSISTENCE
  // ══════════════════════════════════════════════

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_tokenKey, _token!);
    if (_user != null) await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

// ══════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════

class TorqueLoginPayload {
  final String statement;
  final String issuedAt;
  final String expirationTime;

  TorqueLoginPayload({required this.statement, required this.issuedAt, required this.expirationTime});

  factory TorqueLoginPayload.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] ?? json;
    return TorqueLoginPayload(
      statement: payload['statement'] ?? '',
      issuedAt: payload['issuedAt'] ?? '',
      expirationTime: payload['expirationTime'] ?? '',
    );
  }
}

class TorqueUser {
  final String pubKey;
  final String? username;
  final String? twitter;
  final String? profileImage;
  final bool isPublisher;
  final String? publisherPubKey;
  final String? token;
  final String? telegram;

  TorqueUser({
    required this.pubKey,
    this.username,
    this.twitter,
    this.profileImage,
    this.isPublisher = false,
    this.publisherPubKey,
    this.token,
    this.telegram,
  });

  String get displayName => username ?? twitter ?? '${pubKey.substring(0, 6)}...${pubKey.substring(pubKey.length - 4)}';

  factory TorqueUser.fromJson(Map<String, dynamic> json) {
    return TorqueUser(
      pubKey: json['pubKey'] ?? '',
      username: json['username'] as String?,
      twitter: json['twitter'] as String?,
      profileImage: json['profileImage'] as String?,
      isPublisher: json['isPublisher'] == true,
      publisherPubKey: json['publisherPubKey'] as String?,
      token: json['token'] as String?,
      telegram: json['telegram'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'pubKey': pubKey,
    if (username != null) 'username': username,
    if (twitter != null) 'twitter': twitter,
    if (profileImage != null) 'profileImage': profileImage,
    'isPublisher': isPublisher,
    if (publisherPubKey != null) 'publisherPubKey': publisherPubKey,
    if (telegram != null) 'telegram': telegram,
  };
}

class TorqueCampaign {
  final String id;
  final String? type;
  final String? status;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? targetLink;
  final String? advertiserPubKey;
  final Map<String, dynamic>? advertiser;
  final int totalConversions;
  final int remainingConversions;
  final String? userRewardToken;
  final String? userRewardAmount;
  final String? userRewardType;
  final List<Map<String, dynamic>> requirements;
  final List<Map<String, dynamic>> asymmetricRewards;
  final bool hideRewards;
  final DateTime? startTime;
  final DateTime? endTime;

  TorqueCampaign({
    required this.id,
    this.type, this.status, this.title, this.description,
    this.imageUrl, this.targetLink, this.advertiserPubKey, this.advertiser,
    this.totalConversions = 0, this.remainingConversions = 0,
    this.userRewardToken, this.userRewardAmount, this.userRewardType,
    this.requirements = const [], this.asymmetricRewards = const [],
    this.hideRewards = false, this.startTime, this.endTime,
  });

  bool get isActive => status == 'ACTIVE' || status == null;
  bool get hasReward => userRewardAmount != null && !hideRewards;
  String get rewardDisplay {
    if (hideRewards) return '🎁 Hidden reward';
    if (userRewardType == 'POINTS') return '${userRewardAmount ?? "?"} points';
    return '${userRewardAmount ?? "?"} ${userRewardType ?? "tokens"}';
  }

  factory TorqueCampaign.fromJson(Map<String, dynamic> json) {
    return TorqueCampaign(
      id: json['id'] ?? '',
      type: json['type'] as String?,
      status: json['status'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      targetLink: json['targetLink'] as String?,
      advertiserPubKey: json['advertiserPubKey'] as String?,
      advertiser: json['advertiser'] as Map<String, dynamic>?,
      totalConversions: json['totalConversions'] ?? 0,
      remainingConversions: json['remainingConversions'] ?? 0,
      userRewardToken: json['userRewardToken'] as String?,
      userRewardAmount: json['userRewardAmount'] as String?,
      userRewardType: json['userRewardType'] as String?,
      requirements: (json['requirements'] as List? ?? []).cast<Map<String, dynamic>>(),
      asymmetricRewards: (json['asymmetricRewards'] as List? ?? []).cast<Map<String, dynamic>>(),
      hideRewards: json['hideRewards'] == true,
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime'].toString()) : null,
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'].toString()) : null,
    );
  }
}

class TorqueJourney {
  final String? campaignId;
  final String? status;
  final int? currentStep;
  final int? totalSteps;
  final Map<String, dynamic> raw;

  TorqueJourney({this.campaignId, this.status, this.currentStep, this.totalSteps, this.raw = const {}});

  bool get isCompleted => status == 'COMPLETED';
  bool get isActive => status == 'ACTIVE' || status == 'IN_PROGRESS';

  factory TorqueJourney.fromJson(Map<String, dynamic> json) {
    return TorqueJourney(
      campaignId: json['campaignId'] as String?,
      status: json['status'] as String?,
      currentStep: json['currentStep'] as int?,
      totalSteps: json['totalSteps'] as int?,
      raw: json,
    );
  }
}

class TorqueAction {
  final String? transaction; // Base64 encoded VersionedTransaction
  final String? message;
  final String? label;
  final String? icon;
  final Map<String, dynamic> raw;

  TorqueAction({this.transaction, this.message, this.label, this.icon, this.raw = const {}});

  factory TorqueAction.fromJson(Map<String, dynamic> json) {
    return TorqueAction(
      transaction: json['transaction'] as String?,
      message: json['message'] as String?,
      label: json['label'] as String?,
      icon: json['icon'] as String?,
      raw: json,
    );
  }
}

class TorquePayout {
  final String? payoutTx;
  final String? token;
  final double? amount;
  final Map<String, dynamic> raw;

  TorquePayout({this.payoutTx, this.token, this.amount, this.raw = const {}});

  factory TorquePayout.fromJson(Map<String, dynamic> json) {
    return TorquePayout(
      payoutTx: json['payoutTx'] as String?,
      token: json['token'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      raw: json,
    );
  }
}
