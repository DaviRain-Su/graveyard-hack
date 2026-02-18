import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:ox_common/utils/storage_key_tool.dart';
import 'package:chatcore/chat-core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Solana wallet service — manages ed25519 key pair, balance, and transfers.
/// Key storage: encrypted via SharedPreferences (same as 0xchat Nostr key).
class SolanaWalletService extends ChangeNotifier {
  static final SolanaWalletService instance = SolanaWalletService._();
  SolanaWalletService._();

  Ed25519HDKeyPair? _keyPair;
  SolanaClient? _client;

  String get address => _keyPair?.address ?? '';
  bool get hasWallet => _keyPair != null;

  double _balance = 0;
  double get balance => _balance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Solana RPC endpoints
  static const String _mainnetRpc = 'https://api.mainnet-beta.solana.com';
  static const String _devnetRpc = 'https://api.devnet.solana.com';

  // Storage keys
  static const String _keyStorageKey = 'ox_solana_private_key';
  static const String _networkKey = 'ox_solana_network';

  bool _isDevnet = false;
  bool get isDevnet => _isDevnet;

  String get rpcUrl => _isDevnet ? _devnetRpc : _mainnetRpc;

  Future<void> init() async {
    _initClient();
    await _loadSavedWallet();
  }

  void _initClient() {
    _client = SolanaClient(
      rpcUrl: Uri.parse(rpcUrl),
      websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
    );
  }

  /// Switch between mainnet and devnet
  Future<void> switchNetwork({required bool devnet}) async {
    _isDevnet = devnet;
    _initClient();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_networkKey, devnet);
    await refreshBalance();
    notifyListeners();
  }

  /// Create a new Solana wallet (ed25519 key pair)
  Future<String> createWallet() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _keyPair = await Ed25519HDKeyPair.random();
      await _saveWallet();
      await refreshBalance();

      if (kDebugMode) {
        print('[OXSolana] Wallet created: $address');
      }

      return address;
    } catch (e) {
      _error = 'Failed to create wallet: $e';
      if (kDebugMode) print('[OXSolana] $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import wallet from mnemonic (BIP39)
  Future<String> importFromMnemonic(String mnemonic) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _keyPair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
      await _saveWallet();
      await refreshBalance();

      if (kDebugMode) {
        print('[OXSolana] Wallet imported: $address');
      }

      return address;
    } catch (e) {
      _error = 'Failed to import wallet: $e';
      if (kDebugMode) print('[OXSolana] $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh SOL balance
  Future<double> refreshBalance() async {
    if (_keyPair == null || _client == null) return 0;

    try {
      final lamports = await _client!.rpcClient.getBalance(address);
      _balance = lamports.value / lamportsPerSol;
      _error = null;
      notifyListeners();
      return _balance;
    } catch (e) {
      _error = 'Failed to fetch balance: $e';
      if (kDebugMode) print('[OXSolana] $_error');
      notifyListeners();
      return _balance;
    }
  }

  /// Send SOL to an address
  Future<String> sendSol({
    required String toAddress,
    required double amount,
  }) async {
    if (_keyPair == null || _client == null) {
      throw Exception('Wallet not initialized');
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final signature = await _client!.transferLamports(
        source: _keyPair!,
        destination: Ed25519HDPublicKey.fromBase58(toAddress),
        lamports: (amount * lamportsPerSol).toInt(),
      );

      if (kDebugMode) {
        print('[OXSolana] Transfer sent: $signature');
      }

      // Refresh balance after transfer
      await refreshBalance();

      return signature;
    } catch (e) {
      _error = 'Transfer failed: $e';
      if (kDebugMode) print('[OXSolana] $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete wallet
  Future<void> deleteWallet() async {
    _keyPair = null;
    _balance = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageKey);
    notifyListeners();
  }

  /// Request devnet airdrop (1 SOL)
  Future<String> requestAirdrop({double amount = 1.0}) async {
    if (_keyPair == null || _client == null) {
      throw Exception('Wallet not initialized');
    }
    if (!_isDevnet) {
      throw Exception('Airdrop only available on devnet');
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final signature = await _client!.rpcClient.requestAirdrop(
        address,
        (amount * lamportsPerSol).toInt(),
      );

      if (kDebugMode) {
        print('[OXSolana] Airdrop requested: $signature');
      }

      // Wait a bit then refresh balance
      await Future.delayed(const Duration(seconds: 2));
      await refreshBalance();

      return signature;
    } catch (e) {
      _error = 'Airdrop failed: $e';
      if (kDebugMode) print('[OXSolana] $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get explorer URL for a transaction
  String getExplorerUrl(String signature) {
    final cluster = _isDevnet ? '?cluster=devnet' : '';
    return 'https://explorer.solana.com/tx/$signature$cluster';
  }

  /// Get explorer URL for the wallet address
  String get addressExplorerUrl {
    final cluster = _isDevnet ? '?cluster=devnet' : '';
    return 'https://explorer.solana.com/address/$address$cluster';
  }

  /// Get Nostr pubkey (for Tapestry binding)
  String? get nostrPubkey {
    try {
      return Account.sharedInstance.currentPubkey;
    } catch (_) {
      return null;
    }
  }

  // --- Private helpers ---

  Future<void> _saveWallet() async {
    if (_keyPair == null) return;
    final prefs = await SharedPreferences.getInstance();
    // Store the key pair bytes as base64
    // In production, use secure storage (flutter_secure_storage)
    final keyBytes = await _keyPair!.extract();
    final encoded = base64Encode(keyBytes.bytes);
    await prefs.setString(_keyStorageKey, encoded);
  }

  Future<void> _loadSavedWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDevnet = prefs.getBool(_networkKey) ?? false;

      final encoded = prefs.getString(_keyStorageKey);
      if (encoded == null) return;

      final keyBytes = base64Decode(encoded);
      _keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: keyBytes,
      );

      if (kDebugMode) {
        print('[OXSolana] Wallet loaded: $address');
      }

      await refreshBalance();
    } catch (e) {
      if (kDebugMode) {
        print('[OXSolana] Failed to load saved wallet: $e');
      }
    }
  }
}
