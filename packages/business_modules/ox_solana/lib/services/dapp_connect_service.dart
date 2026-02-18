import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'solana_wallet_service.dart';

/// DApp connection service — lightweight alternative to full WalletConnect.
///
/// Supports:
/// 1. Phantom-style deep link protocol (connect, signTransaction, signMessage)
/// 2. Simple JSON-RPC bridge for embedded WebView dApps
/// 3. Connected dApp session management
///
/// Phase 1: Session management + sign message + simulate approval UI
/// Phase 2: Full WalletConnect v2 integration (walletconnect_flutter_v2)
class DappConnectService {
  static final DappConnectService instance = DappConnectService._();
  DappConnectService._();

  static const String _storageKey = 'ox_solana_dapp_sessions';

  final Map<String, DappSession> _sessions = {};
  Map<String, DappSession> get sessions => Map.unmodifiable(_sessions);

  final _listeners = <VoidCallback>[];
  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);
  void _notify() { for (final cb in _listeners) cb(); }

  /// Initialize — load saved sessions
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json != null) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _sessions[entry.key] = DappSession.fromJson(entry.value);
        }
        // Clean expired sessions (>7 days)
        _sessions.removeWhere((_, s) =>
            DateTime.now().difference(s.connectedAt).inDays > 7);
      } catch (e) {
        if (kDebugMode) print('[DApp] Load error: $e');
      }
    }
    if (kDebugMode) print('[DApp] Init: ${_sessions.length} active sessions');
  }

  /// Connect a dApp — create session
  DappSession connect({
    required String dappName,
    required String dappUrl,
    String? dappIcon,
    List<String> permissions = const ['signTransaction', 'signMessage'],
  }) {
    final wallet = SolanaWalletService.instance;
    if (!wallet.hasWallet) throw Exception('No wallet available');

    final session = DappSession(
      id: _generateSessionId(),
      dappName: dappName,
      dappUrl: dappUrl,
      dappIcon: dappIcon,
      walletAddress: wallet.address,
      permissions: permissions,
      connectedAt: DateTime.now(),
      isDevnet: !wallet.isMainnet,
    );

    _sessions[session.id] = session;
    _save();
    _notify();

    if (kDebugMode) print('[DApp] Connected: ${session.dappName} (${session.id})');
    return session;
  }

  /// Disconnect a dApp session
  void disconnect(String sessionId) {
    _sessions.remove(sessionId);
    _save();
    _notify();
    if (kDebugMode) print('[DApp] Disconnected: $sessionId');
  }

  /// Disconnect all sessions
  void disconnectAll() {
    _sessions.clear();
    _save();
    _notify();
  }

  /// Sign a message (returns base64 signature)
  Future<String?> signMessage({
    required String sessionId,
    required Uint8List message,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) throw Exception('Session not found');
    if (!session.permissions.contains('signMessage')) {
      throw Exception('signMessage not permitted');
    }

    final wallet = SolanaWalletService.instance;
    if (wallet.keyPair == null) throw Exception('No wallet available');

    try {
      final signature = await wallet.keyPair!.sign(message);
      session.lastActive = DateTime.now();
      _save();
      return base64Encode(signature.bytes);
    } catch (e) {
      if (kDebugMode) print('[DApp] Sign error: $e');
      return null;
    }
  }

  /// Get session by ID
  DappSession? getSession(String id) => _sessions[id];

  /// Check if a dApp URL is already connected
  DappSession? getSessionByUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return _sessions.values.firstWhere(
        (s) => Uri.parse(s.dappUrl).host == uri.host,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse Phantom-style deep link
  /// Format: phantom://v1/connect?app_url=...&redirect_link=...
  static DappConnectRequest? parseDeepLink(String link) {
    try {
      final uri = Uri.parse(link);
      if (uri.scheme == 'phantom' || uri.host == 'phantom') {
        final method = uri.pathSegments.lastOrNull ?? '';
        return DappConnectRequest(
          method: method,
          appUrl: uri.queryParameters['app_url'] ?? '',
          redirectLink: uri.queryParameters['redirect_link'],
          payload: uri.queryParameters['payload'],
        );
      }
    } catch (_) {}
    return null;
  }

  // ===================== PRIVATE =====================

  String _generateSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'dapp_${now.toRadixString(36)}';
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _sessions.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}

/// DApp session model
class DappSession {
  final String id;
  final String dappName;
  final String dappUrl;
  final String? dappIcon;
  final String walletAddress;
  final List<String> permissions;
  final DateTime connectedAt;
  final bool isDevnet;
  DateTime lastActive;

  DappSession({
    required this.id,
    required this.dappName,
    required this.dappUrl,
    this.dappIcon,
    required this.walletAddress,
    required this.permissions,
    required this.connectedAt,
    this.isDevnet = false,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  String get shortAddress =>
      '${walletAddress.substring(0, 4)}...${walletAddress.substring(walletAddress.length - 4)}';

  String get domain {
    try {
      return Uri.parse(dappUrl).host;
    } catch (_) {
      return dappUrl;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dapp_name': dappName,
        'dapp_url': dappUrl,
        'dapp_icon': dappIcon,
        'wallet_address': walletAddress,
        'permissions': permissions,
        'connected_at': connectedAt.toIso8601String(),
        'last_active': lastActive.toIso8601String(),
        'is_devnet': isDevnet,
      };

  factory DappSession.fromJson(Map<String, dynamic> json) {
    return DappSession(
      id: json['id'] ?? '',
      dappName: json['dapp_name'] ?? '',
      dappUrl: json['dapp_url'] ?? '',
      dappIcon: json['dapp_icon'],
      walletAddress: json['wallet_address'] ?? '',
      permissions: List<String>.from(json['permissions'] ?? []),
      connectedAt: DateTime.tryParse(json['connected_at'] ?? '') ?? DateTime.now(),
      lastActive: DateTime.tryParse(json['last_active'] ?? '') ?? DateTime.now(),
      isDevnet: json['is_devnet'] ?? false,
    );
  }
}

/// Parsed deep link request
class DappConnectRequest {
  final String method; // connect, signTransaction, signMessage, disconnect
  final String appUrl;
  final String? redirectLink;
  final String? payload;

  const DappConnectRequest({
    required this.method,
    required this.appUrl,
    this.redirectLink,
    this.payload,
  });
}
