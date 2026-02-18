import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:solana/solana.dart';

import 'solana_wallet_service.dart';

/// Jupiter DEX aggregator service — swap tokens on Solana.
/// API: https://quote-api.jup.ag/v6
class JupiterService {
  static final JupiterService instance = JupiterService._();
  JupiterService._();

  static const String _baseUrl = 'https://quote-api.jup.ag/v6';

  // Well-known token mints
  static const String solMint = 'So11111111111111111111111111111111111111112';
  static const String usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
  static const String usdtMint = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';
  static const String bonkMint = 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263';
  static const String jupMint = 'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN';

  static const List<SwapToken> popularTokens = [
    SwapToken(symbol: 'SOL', name: 'Solana', mint: solMint, decimals: 9, logoChar: 'S'),
    SwapToken(symbol: 'USDC', name: 'USD Coin', mint: usdcMint, decimals: 6, logoChar: 'U'),
    SwapToken(symbol: 'USDT', name: 'Tether USD', mint: usdtMint, decimals: 6, logoChar: 'T'),
    SwapToken(symbol: 'BONK', name: 'Bonk', mint: bonkMint, decimals: 5, logoChar: 'B'),
    SwapToken(symbol: 'JUP', name: 'Jupiter', mint: jupMint, decimals: 6, logoChar: 'J'),
  ];

  /// Get swap quote from Jupiter
  Future<JupiterQuote?> getQuote({
    required String inputMint,
    required String outputMint,
    required int amount, // in smallest unit (lamports for SOL)
    int slippageBps = 50, // 0.5%
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/quote').replace(queryParameters: {
        'inputMint': inputMint,
        'outputMint': outputMint,
        'amount': amount.toString(),
        'slippageBps': slippageBps.toString(),
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return JupiterQuote.fromJson(data);
      } else {
        if (kDebugMode) {
          print('[Jupiter] Quote error: ${response.statusCode} ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('[Jupiter] Quote exception: $e');
      return null;
    }
  }

  /// Get swap transaction from Jupiter (serialized)
  Future<String?> getSwapTransaction({
    required Map<String, dynamic> quoteResponse,
    required String userPublicKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/swap'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'quoteResponse': quoteResponse,
          'userPublicKey': userPublicKey,
          'wrapAndUnwrapSol': true,
          'dynamicComputeUnitLimit': true,
          'prioritizationFeeLamports': 'auto',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['swapTransaction'] as String?;
      } else {
        if (kDebugMode) {
          print('[Jupiter] Swap tx error: ${response.statusCode} ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('[Jupiter] Swap tx exception: $e');
      return null;
    }
  }

  /// Execute a full swap: quote → get tx → sign → send
  Future<String> executeSwap({
    required String inputMint,
    required String outputMint,
    required int amount,
    int slippageBps = 50,
  }) async {
    final wallet = SolanaWalletService.instance;
    if (!wallet.hasWallet) throw Exception('Wallet not initialized');

    // 1. Get quote
    final quote = await getQuote(
      inputMint: inputMint,
      outputMint: outputMint,
      amount: amount,
      slippageBps: slippageBps,
    );
    if (quote == null) throw Exception('Failed to get swap quote');

    // 2. Get serialized transaction
    final swapTxBase64 = await getSwapTransaction(
      quoteResponse: quote.rawResponse,
      userPublicKey: wallet.address,
    );
    if (swapTxBase64 == null) throw Exception('Failed to build swap transaction');

    // 3. Deserialize, sign, and send
    final txBytes = base64Decode(swapTxBase64);
    final client = SolanaClient(
      rpcUrl: Uri.parse(wallet.rpcUrl),
      websocketUrl: Uri.parse(wallet.rpcUrl.replaceFirst('https', 'wss')),
    );

    // Send raw transaction
    final signature = await client.rpcClient.sendTransaction(
      base64Encode(txBytes),
      preflightCommitment: Commitment.confirmed,
    );

    if (kDebugMode) {
      print('[Jupiter] Swap executed: $signature');
    }

    // Refresh balances
    await wallet.refreshBalance();
    await wallet.fetchTokens();

    return signature;
  }
}

/// Jupiter quote response
class JupiterQuote {
  final String inputMint;
  final String outputMint;
  final String inAmount;
  final String outAmount;
  final double priceImpactPct;
  final List<dynamic> routePlan;
  final Map<String, dynamic> rawResponse;

  JupiterQuote({
    required this.inputMint,
    required this.outputMint,
    required this.inAmount,
    required this.outAmount,
    required this.priceImpactPct,
    required this.routePlan,
    required this.rawResponse,
  });

  factory JupiterQuote.fromJson(Map<String, dynamic> json) {
    return JupiterQuote(
      inputMint: json['inputMint'] as String? ?? '',
      outputMint: json['outputMint'] as String? ?? '',
      inAmount: json['inAmount'] as String? ?? '0',
      outAmount: json['outAmount'] as String? ?? '0',
      priceImpactPct: double.tryParse(json['priceImpactPct']?.toString() ?? '0') ?? 0,
      routePlan: json['routePlan'] as List? ?? [],
      rawResponse: json,
    );
  }

  /// Human-readable output amount
  String outAmountDisplay(int decimals) {
    final raw = int.tryParse(outAmount) ?? 0;
    final amount = raw / _pow10(decimals);
    return amount.toStringAsFixed(decimals.clamp(0, 6));
  }

  /// Human-readable input amount
  String inAmountDisplay(int decimals) {
    final raw = int.tryParse(inAmount) ?? 0;
    final amount = raw / _pow10(decimals);
    return amount.toStringAsFixed(decimals.clamp(0, 6));
  }

  static double _pow10(int n) {
    double result = 1;
    for (int i = 0; i < n; i++) result *= 10;
    return result;
  }
}

/// Swap token info
class SwapToken {
  final String symbol;
  final String name;
  final String mint;
  final int decimals;
  final String logoChar;

  const SwapToken({
    required this.symbol,
    required this.name,
    required this.mint,
    required this.decimals,
    required this.logoChar,
  });
}
