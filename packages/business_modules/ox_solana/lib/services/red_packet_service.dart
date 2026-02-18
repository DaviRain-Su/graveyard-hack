import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'solana_wallet_service.dart';

/// SOL Red Packet (红包) service — send SOL in chat as red packets.
///
/// Design:
/// - Sender creates a red packet with total amount + count
/// - Red packet info sent as Nostr template message
/// - Recipients claim by providing their Solana address
/// - Sender's wallet auto-transfers to claimants
/// - Unclaimed packets expire after 24h and are refunded
///
/// Phase 1 (current): Sender-custodied — SOL stays in sender wallet until claimed
/// Phase 2 (future): Smart contract escrow — SOL locked in program
class RedPacketService {
  static final RedPacketService instance = RedPacketService._();
  RedPacketService._();

  static const String _storageKey = 'ox_solana_red_packets';

  // Active red packets created by this user
  final Map<String, RedPacket> _activePackets = {};
  Map<String, RedPacket> get activePackets => Map.unmodifiable(_activePackets);

  /// Initialize — load saved red packets
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json != null) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _activePackets[entry.key] = RedPacket.fromJson(entry.value);
        }
        // Clean up expired packets
        _cleanExpired();
      } catch (e) {
        if (kDebugMode) print('[RedPacket] Load error: $e');
      }
    }
    if (kDebugMode) print('[RedPacket] Init: ${_activePackets.length} active packets');
  }

  /// Create a new red packet
  RedPacket createRedPacket({
    required double totalAmount,
    required int count,
    RedPacketType type = RedPacketType.random,
    String? message,
    String? senderNostrPubkey,
  }) {
    if (totalAmount <= 0) throw Exception('Amount must be positive');
    if (count <= 0) throw Exception('Count must be positive');
    if (totalAmount < count * 0.001) {
      throw Exception('Minimum 0.001 SOL per packet');
    }

    final balance = SolanaWalletService.instance.balance;
    // Reserve 0.01 SOL for tx fees
    if (totalAmount > balance - 0.01) {
      throw Exception('Insufficient balance (need ${totalAmount + 0.01} SOL, have $balance SOL)');
    }

    final packet = RedPacket(
      id: _generateId(),
      totalAmount: totalAmount,
      count: count,
      type: type,
      message: message ?? '恭喜发财，大吉大利！',
      senderAddress: SolanaWalletService.instance.address,
      senderNostrPubkey: senderNostrPubkey ?? '',
      createdAt: DateTime.now(),
      claims: [],
      isDevnet: SolanaWalletService.instance.isDevnet,
    );

    // Pre-split amounts
    packet.splitAmounts = _splitAmount(totalAmount, count, type);

    _activePackets[packet.id] = packet;
    _save();

    if (kDebugMode) {
      print('[RedPacket] Created: ${packet.id} — $totalAmount SOL x $count (${type.name})');
    }

    return packet;
  }

  /// Claim a red packet — returns amount claimed (0 if already claimed or exhausted)
  Future<double> claimRedPacket({
    required String packetId,
    required String claimerSolAddress,
    required String claimerNostrPubkey,
  }) async {
    final packet = _activePackets[packetId];
    if (packet == null) throw Exception('Red packet not found or expired');
    if (packet.isFullyClaimed) throw Exception('Red packet is empty');
    if (packet.isExpired) throw Exception('Red packet has expired');

    // Check if already claimed
    if (packet.claims.any((c) => c.nostrPubkey == claimerNostrPubkey)) {
      throw Exception('You already claimed this red packet');
    }

    // Get next amount
    final claimIndex = packet.claims.length;
    final amount = packet.splitAmounts[claimIndex];

    // Execute transfer
    final wallet = SolanaWalletService.instance;
    final signature = await wallet.sendSol(
      toAddress: claimerSolAddress,
      amount: amount,
    );

    // Record claim
    packet.claims.add(RedPacketClaim(
      nostrPubkey: claimerNostrPubkey,
      solAddress: claimerSolAddress,
      amount: amount,
      signature: signature,
      claimedAt: DateTime.now(),
    ));

    _save();

    if (kDebugMode) {
      print('[RedPacket] Claimed: $packetId — $amount SOL to ${claimerSolAddress.substring(0, 8)}...');
    }

    return amount;
  }

  /// Get red packet status for display
  RedPacket? getPacket(String id) => _activePackets[id];

  /// Generate red packet message payload for Nostr template message
  Map<String, dynamic> createMessagePayload(RedPacket packet) {
    return {
      'type': 'sol_red_packet',
      'id': packet.id,
      'total_amount': packet.totalAmount.toString(),
      'count': packet.count,
      'packet_type': packet.type.name,
      'message': packet.message,
      'sender_address': packet.senderAddress,
      'sender_nostr_pubkey': packet.senderNostrPubkey,
      'is_devnet': packet.isDevnet,
      'created_at': packet.createdAt.toIso8601String(),
    };
  }

  /// Parse incoming red packet message
  static RedPacketMessage? parseMessage(String content) {
    try {
      final data = jsonDecode(content);
      if (data['type'] == 'sol_red_packet') {
        return RedPacketMessage(
          id: data['id'] ?? '',
          totalAmount: double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0,
          count: data['count'] ?? 1,
          message: data['message'] ?? '',
          senderAddress: data['sender_address'] ?? '',
          senderNostrPubkey: data['sender_nostr_pubkey'] ?? '',
          isDevnet: data['is_devnet'] ?? false,
        );
      }
    } catch (_) {}
    return null;
  }

  // ===================== PRIVATE =====================

  List<double> _splitAmount(double total, int count, RedPacketType type) {
    if (type == RedPacketType.equal) {
      final each = (total / count * 10000).floor() / 10000; // floor to 4 decimals
      final amounts = List.filled(count, each);
      // Put remainder in last packet
      final distributed = each * (count - 1);
      amounts[count - 1] = double.parse((total - distributed).toStringAsFixed(4));
      return amounts;
    }

    // Random split (微信红包算法)
    final rng = Random();
    final amounts = <double>[];
    double remaining = total;

    for (int i = 0; i < count - 1; i++) {
      final remainCount = count - i;
      // Each person gets at least 0.001 SOL
      final maxAmount = remaining - (remainCount - 1) * 0.001;
      // Random range: [0.001, 2 * average]
      final avgRemaining = remaining / remainCount;
      final upper = min(maxAmount, avgRemaining * 2);
      final amount = max(0.001, rng.nextDouble() * upper);
      final rounded = double.parse(amount.toStringAsFixed(4));
      amounts.add(rounded);
      remaining -= rounded;
    }
    // Last person gets remainder
    amounts.add(double.parse(remaining.toStringAsFixed(4)));

    return amounts;
  }

  String _generateId() {
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _cleanExpired() {
    _activePackets.removeWhere((_, p) => p.isExpired && p.isFullyClaimed);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _activePackets.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}

// ===================== MODELS =====================

enum RedPacketType { random, equal }

class RedPacket {
  final String id;
  final double totalAmount;
  final int count;
  final RedPacketType type;
  final String message;
  final String senderAddress;
  final String senderNostrPubkey;
  final DateTime createdAt;
  final List<RedPacketClaim> claims;
  final bool isDevnet;
  List<double> splitAmounts;

  RedPacket({
    required this.id,
    required this.totalAmount,
    required this.count,
    required this.type,
    required this.message,
    required this.senderAddress,
    required this.senderNostrPubkey,
    required this.createdAt,
    required this.claims,
    required this.isDevnet,
    List<double>? splitAmounts,
  }) : splitAmounts = splitAmounts ?? [];

  bool get isFullyClaimed => claims.length >= count;
  bool get isExpired => DateTime.now().difference(createdAt).inHours >= 24;
  double get claimedAmount => claims.fold(0.0, (sum, c) => sum + c.amount);
  double get remainingAmount => totalAmount - claimedAmount;
  int get remainingCount => count - claims.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'total_amount': totalAmount,
    'count': count,
    'type': type.name,
    'message': message,
    'sender_address': senderAddress,
    'sender_nostr_pubkey': senderNostrPubkey,
    'created_at': createdAt.toIso8601String(),
    'is_devnet': isDevnet,
    'split_amounts': splitAmounts,
    'claims': claims.map((c) => c.toJson()).toList(),
  };

  factory RedPacket.fromJson(Map<String, dynamic> json) {
    return RedPacket(
      id: json['id'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      count: json['count'] ?? 1,
      type: json['type'] == 'equal' ? RedPacketType.equal : RedPacketType.random,
      message: json['message'] ?? '',
      senderAddress: json['sender_address'] ?? '',
      senderNostrPubkey: json['sender_nostr_pubkey'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isDevnet: json['is_devnet'] ?? false,
      splitAmounts: (json['split_amounts'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      claims: (json['claims'] as List?)?.map((c) => RedPacketClaim.fromJson(c)).toList() ?? [],
    );
  }
}

class RedPacketClaim {
  final String nostrPubkey;
  final String solAddress;
  final double amount;
  final String signature;
  final DateTime claimedAt;

  RedPacketClaim({
    required this.nostrPubkey,
    required this.solAddress,
    required this.amount,
    required this.signature,
    required this.claimedAt,
  });

  Map<String, dynamic> toJson() => {
    'nostr_pubkey': nostrPubkey,
    'sol_address': solAddress,
    'amount': amount,
    'signature': signature,
    'claimed_at': claimedAt.toIso8601String(),
  };

  factory RedPacketClaim.fromJson(Map<String, dynamic> json) {
    return RedPacketClaim(
      nostrPubkey: json['nostr_pubkey'] ?? '',
      solAddress: json['sol_address'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      signature: json['signature'] ?? '',
      claimedAt: DateTime.tryParse(json['claimed_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Parsed red packet from incoming message
class RedPacketMessage {
  final String id;
  final double totalAmount;
  final int count;
  final String message;
  final String senderAddress;
  final String senderNostrPubkey;
  final bool isDevnet;

  const RedPacketMessage({
    required this.id,
    required this.totalAmount,
    required this.count,
    required this.message,
    required this.senderAddress,
    required this.senderNostrPubkey,
    this.isDevnet = false,
  });
}
