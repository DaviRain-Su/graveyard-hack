import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Token price service — fetches USD prices from CoinGecko.
/// Free API, no key needed. Rate limit: ~10-30 req/min.
class PriceService {
  static final PriceService instance = PriceService._();
  PriceService._();

  static const String _baseUrl = 'https://api.coingecko.com/api/v3';

  // Mint address → CoinGecko ID mapping
  static const Map<String, String> _mintToGeckoId = {
    'So11111111111111111111111111111111111111112': 'solana',
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': 'usd-coin',
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB': 'tether',
    'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263': 'bonk',
    'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN': 'jupiter-exchange-solana',
    'mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So': 'msol',
    '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs': 'ethereum',  // wETH
    'rndrizKT3MK1iimdxRdWabcF7Zg7AR5T4nud4EkHBof': 'render-token',
    'HZ1JovNiVvGrGNiiYvEozEVgZ58xaU3RKwX8eACQBCt3': 'pyth-network',
    'hntyVP6YFm1Hg25TN9WGLqM12b8TQmcknKrdu1oxWux': 'helium',
  };

  // Cache: geckoId → price USD
  final Map<String, double> _priceCache = {};
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(seconds: 60);

  /// Get USD price for a token mint address
  double? getPrice(String mintAddress) {
    final geckoId = _mintToGeckoId[mintAddress];
    if (geckoId == null) return null;
    return _priceCache[geckoId];
  }

  /// Get SOL price in USD
  double get solPrice => _priceCache['solana'] ?? 0;

  /// Check if prices are loaded
  bool get hasPrices => _priceCache.isNotEmpty;

  /// Fetch all token prices (batched)
  Future<void> fetchPrices() async {
    // Rate limit: don't fetch too often
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return;
    }

    try {
      final geckoIds = _mintToGeckoId.values.toSet().join(',');
      final uri = Uri.parse(
          '$_baseUrl/simple/price?ids=$geckoIds&vs_currencies=usd');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        for (final entry in data.entries) {
          final usd = entry.value['usd'];
          if (usd != null) {
            _priceCache[entry.key] = (usd as num).toDouble();
          }
        }
        _lastFetch = DateTime.now();
        if (kDebugMode) {
          print('[PriceService] Fetched ${_priceCache.length} prices, SOL=\$${solPrice}');
        }
      } else if (response.statusCode == 429) {
        if (kDebugMode) print('[PriceService] Rate limited, using cache');
      }
    } catch (e) {
      if (kDebugMode) print('[PriceService] Fetch error: $e');
    }
  }

  /// Get formatted USD value string
  String formatUsdValue(double tokenAmount, String mintAddress) {
    final price = getPrice(mintAddress);
    if (price == null) return '';
    final value = tokenAmount * price;
    if (value < 0.01) return '<\$0.01';
    if (value < 100) return '\$${value.toStringAsFixed(2)}';
    return '\$${value.toStringAsFixed(0)}';
  }

  /// Format just the price
  String formatPrice(String mintAddress) {
    final price = getPrice(mintAddress);
    if (price == null) return '';
    if (price < 0.001) return '\$${price.toStringAsExponential(2)}';
    if (price < 1) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(2)}';
  }
}
