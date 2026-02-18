/// Solana transaction record for history display
class TransactionRecord {
  final String signature;
  final int slot;
  final int? blockTime;
  final bool isError;
  final String? memo;
  final String? confirmationStatus;

  const TransactionRecord({
    required this.signature,
    required this.slot,
    this.blockTime,
    this.isError = false,
    this.memo,
    this.confirmationStatus,
  });

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
