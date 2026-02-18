/// Solana transaction record for history display
class TransactionRecord {
  final String signature;
  final int slot;
  final int? blockTime;
  final bool isError;
  final String? memo;
  final String? confirmationStatus;

  /// SOL amount change for our wallet (negative = sent, positive = received)
  /// null if not yet resolved via getTransaction
  final double? solChange;

  /// Fee paid in SOL
  final double? fee;

  const TransactionRecord({
    required this.signature,
    required this.slot,
    this.blockTime,
    this.isError = false,
    this.memo,
    this.confirmationStatus,
    this.solChange,
    this.fee,
  });

  /// Copy with resolved amount data
  TransactionRecord withAmounts({double? solChange, double? fee}) {
    return TransactionRecord(
      signature: signature,
      slot: slot,
      blockTime: blockTime,
      isError: isError,
      memo: memo,
      confirmationStatus: confirmationStatus,
      solChange: solChange ?? this.solChange,
      fee: fee ?? this.fee,
    );
  }

  /// Whether this is a send or receive
  bool get isSend => (solChange ?? 0) < 0;
  bool get isReceive => (solChange ?? 0) > 0;

  /// Formatted amount display
  String get amountDisplay {
    if (solChange == null) return '';
    final abs = solChange!.abs();
    final sign = solChange! >= 0 ? '+' : '-';
    return '$sign${abs.toStringAsFixed(4)} SOL';
  }

  String get shortSignature =>
      '${signature.substring(0, 8)}...${signature.substring(signature.length - 8)}';

  String get timeDisplay {
    if (blockTime == null) return 'Pending...';
    final dt = DateTime.fromMillisecondsSinceEpoch(blockTime! * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String get statusDisplay {
    if (isError) return 'Failed';
    return confirmationStatus ?? 'Confirmed';
  }
}
