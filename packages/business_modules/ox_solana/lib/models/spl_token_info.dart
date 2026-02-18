/// SPL Token information model
class SplTokenInfo {
  final String mintAddress;
  final String tokenAccountAddress;
  final double balance;
  final int decimals;
  final String symbol;
  final String name;
  final String? logoUrl;

  const SplTokenInfo({
    required this.mintAddress,
    required this.tokenAccountAddress,
    required this.balance,
    required this.decimals,
    this.symbol = 'Unknown',
    this.name = 'Unknown Token',
    this.logoUrl,
  });

  /// UI-friendly amount (same as balance, already divided by decimals)
  double get uiAmount => balance;

  String get shortMint =>
      '${mintAddress.substring(0, 6)}...${mintAddress.substring(mintAddress.length - 4)}';

  String get balanceDisplay {
    if (balance == 0) return '0';
    if (balance < 0.0001) return '<0.0001';
    return balance.toStringAsFixed(decimals.clamp(0, 6));
  }

  @override
  String toString() => '$symbol: $balanceDisplay ($shortMint)';
}

/// Well-known SPL tokens on Solana (mainnet + devnet)
class WellKnownTokens {
  static const Map<String, TokenMeta> mainnet = {
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': TokenMeta('USDC', 'USD Coin', 6),
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB': TokenMeta('USDT', 'Tether USD', 6),
    'So11111111111111111111111111111111111111112': TokenMeta('wSOL', 'Wrapped SOL', 9),
    'mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So': TokenMeta('mSOL', 'Marinade Staked SOL', 9),
    'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263': TokenMeta('BONK', 'Bonk', 5),
    'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN': TokenMeta('JUP', 'Jupiter', 6),
    '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs': TokenMeta('ETH', 'Wrapped Ether (Wormhole)', 8),
    'rndrizKT3MK1iimdxRdWabcF7Zg7AR5T4nud4EkHBof': TokenMeta('RENDER', 'Render Token', 8),
    'HZ1JovNiVvGrGNiiYvEozEVgZ58xaU3RKwX8eACQBCt3': TokenMeta('PYTH', 'Pyth Network', 6),
    'hntyVP6YFm1Hg25TN9WGLqM12b8TQmcknKrdu1oxWux': TokenMeta('HNT', 'Helium', 8),
  };

  static const Map<String, TokenMeta> devnet = {
    // Devnet usually has different mint addresses; we'll resolve dynamically
  };

  static TokenMeta? lookup(String mint, {bool isDevnet = false}) {
    if (isDevnet) {
      return devnet[mint] ?? mainnet[mint];
    }
    return mainnet[mint];
  }
}

class TokenMeta {
  final String symbol;
  final String name;
  final int decimals;

  const TokenMeta(this.symbol, this.name, this.decimals);
}
