import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';

import 'solana_wallet_service.dart';

/// Jupiter DEX aggregator service — swap tokens on Solana.
/// API: https://lite-api.jup.ag/swap/v1 (free public endpoint, mainnet only)
/// Note: Jupiter only works on mainnet — no devnet support.
class JupiterService {
  static final JupiterService instance = JupiterService._();
  JupiterService._();

  static const String _baseUrl = 'https://lite-api.jup.ag/swap/v1';

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

  /// Check if Jupiter swap is available (mainnet only)
  static bool isAvailable() {
    return SolanaWalletService.instance.isMainnet;
  }

  /// Get swap quote from Jupiter
  Future<JupiterQuote?> getQuote({
    required String inputMint,
    required String outputMint,
    required int amount, // in smallest unit (lamports for SOL)
    int slippageBps = 50, // 0.5%
  }) async {
    if (!SolanaWalletService.instance.isMainnet) {
      throw Exception('Jupiter swap is only available on mainnet. Switch to mainnet first.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/quote').replace(queryParameters: {
        'inputMint': inputMint,
        'outputMint': outputMint,
        'amount': amount.toString(),
        'slippageBps': slippageBps.toString(),
      });

      if (kDebugMode) print('[Jupiter] Quote URL: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('[Jupiter] Quote success: inAmount=${data['inAmount']} outAmount=${data['outAmount']}');
        return JupiterQuote.fromJson(data);
      } else {
        if (kDebugMode) {
          print('[Jupiter] Quote error: ${response.statusCode} ${response.body}');
        }
        throw Exception('Quote failed (${response.statusCode}): ${_parseError(response.body)}');
      }
    } catch (e) {
      if (kDebugMode) print('[Jupiter] Quote exception: $e');
      rethrow;
    }
  }

  /// Parse error message from Jupiter API response
  static String _parseError(String body) {
    try {
      final json = jsonDecode(body);
      return json['error']?.toString() ?? json['message']?.toString() ?? body;
    } catch (_) {
      return body.length > 100 ? '${body.substring(0, 100)}...' : body;
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
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['swapTransaction'] as String?;
      } else {
        if (kDebugMode) {
          print('[Jupiter] Swap tx error: ${response.statusCode} ${response.body}');
        }
        throw Exception('Swap transaction failed: ${_parseError(response.body)}');
      }
    } catch (e) {
      if (kDebugMode) print('[Jupiter] Swap tx exception: $e');
      rethrow;
    }
  }

  /// Execute a full swap: quote → get tx → sign locally → send
  Future<String> executeSwap({
    required String inputMint,
    required String outputMint,
    required int amount,
    int slippageBps = 50,
  }) async {
    final wallet = SolanaWalletService.instance;
    if (!wallet.hasWallet) throw Exception('Wallet not initialized');

    final keyPair = wallet.keyPair;
    if (keyPair == null) throw Exception('No key pair available');

    // 1. Get quote
    final quote = await getQuote(
      inputMint: inputMint,
      outputMint: outputMint,
      amount: amount,
      slippageBps: slippageBps,
    );
    if (quote == null) throw Exception('Failed to get swap quote');

    // 2. Get serialized transaction from Jupiter
    final swapTxBase64 = await getSwapTransaction(
      quoteResponse: quote.rawResponse,
      userPublicKey: wallet.address,
    );
    if (swapTxBase64 == null) throw Exception('Failed to build swap transaction');

    // 3. Decode the VersionedTransaction, sign with our keypair, re-encode
    final txBytes = base64Decode(swapTxBase64);
    final unsignedTx = SignedTx.fromBytes(txBytes);

    // Extract message bytes and sign them
    final messageBytes = unsignedTx.compiledMessage.toByteArray();
    final signature = await keyPair.sign(messageBytes.toList());

    // Rebuild SignedTx with our real signature replacing the placeholder
    final signedTx = SignedTx(
      signatures: [
        signature,
        ...unsignedTx.signatures.skip(1), // keep other signers if any
      ],
      compiledMessage: unsignedTx.compiledMessage,
    );

    // 4. Send signed transaction
    final client = SolanaClient(
      rpcUrl: Uri.parse(wallet.rpcUrl),
      websocketUrl: Uri.parse(wallet.rpcUrl.replaceFirst('https', 'wss')),
    );

    final txId = await client.rpcClient.sendTransaction(
      signedTx.encode(),
      preflightCommitment: Commitment.confirmed,
    );

    if (kDebugMode) {
      print('[Jupiter] Swap executed: $txId');
    }

    // 5. Refresh balances
    await wallet.refreshBalance();
    await wallet.fetchTokens();

    return txId;
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
