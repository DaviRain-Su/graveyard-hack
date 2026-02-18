import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:solana/dto.dart' hide Account;
import 'package:solana/src/rpc/dto/transaction.dart' as sol_tx;
import 'package:bip39/bip39.dart' as bip39;
import 'package:ox_common/utils/storage_key_tool.dart';
import 'package:chatcore/chat-core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/spl_token_info.dart';
import '../models/transaction_record.dart';

/// Solana wallet service — manages ed25519 key pair, balance, and transfers.
/// Key storage: encrypted via SharedPreferences (same as 0xchat Nostr key).
class SolanaWalletService extends ChangeNotifier {
  static final SolanaWalletService instance = SolanaWalletService._();
  SolanaWalletService._();

  Ed25519HDKeyPair? _keyPair;
  SolanaClient? _client;

  String get address => _keyPair?.address ?? '';
  bool get hasWallet => _keyPair != null;

  /// Expose key pair for transaction signing (used by Jupiter swap)
  Ed25519HDKeyPair? get keyPair => _keyPair;

  double _balance = 0;
  double get balance => _balance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Solana RPC endpoints — default public endpoints
  // Override with setCustomRpc() for production (public endpoints have rate limits)
  static const String _defaultMainnetRpc = 'https://api.mainnet-beta.solana.com';
  static const String _defaultDevnetRpc = 'https://api.devnet.solana.com';
  static const String _customRpcKey = 'ox_solana_custom_rpc';

  String? _customMainnetRpc;
  String get _mainnetRpc => _customMainnetRpc ?? _defaultMainnetRpc;
  String get _devnetRpc => _defaultDevnetRpc;

  // Storage keys — private key & mnemonic go to SecureStorage (Keychain/Keystore)
  // Network preference stays in SharedPreferences (non-sensitive)
  static const String _keyStorageKey = 'ox_solana_private_key';
  static const String _mnemonicStorageKey = 'ox_solana_mnemonic';
  static const String _networkKey = 'ox_solana_network';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // --- Secure storage with macOS Keychain fallback ---
  // macOS debug builds without signing can't use Keychain (-34018).
  // Fallback to SharedPreferences with prefix to keep it distinguishable.
  static const String _fallbackPrefix = '_sec_fb_';

  Future<void> _secureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) print('[OXSolana] SecureStorage write failed ($e), using SharedPreferences fallback');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_fallbackPrefix$key', value);
    }
  }

  Future<String?> _secureRead(String key) async {
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null) return val;
    } catch (e) {
      if (kDebugMode) print('[OXSolana] SecureStorage read failed ($e), trying SharedPreferences fallback');
    }
    // Fallback: check SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_fallbackPrefix$key') ?? prefs.getString(key);
  }

  Future<void> _secureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      if (kDebugMode) print('[OXSolana] SecureStorage delete failed ($e)');
    }
    // Also clear fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_fallbackPrefix$key');
    await prefs.remove(key);
  }

  String? _mnemonic;
  /// Whether wallet was created from mnemonic (can be backed up)
  bool get hasMnemonic => _mnemonic != null;

  bool _isDevnet = false;
  bool get isDevnet => _isDevnet;

  String get rpcUrl => _isDevnet ? _devnetRpc : _mainnetRpc;

  /// Current effective RPC URL for display
  String get effectiveRpcUrl => rpcUrl;

  /// Whether a custom mainnet RPC is configured
  bool get hasCustomRpc => _customMainnetRpc != null;

  /// Set a custom mainnet RPC endpoint (for better rate limits)
  /// Pass null to reset to default
  Future<void> setCustomRpc(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url != null && url.trim().isNotEmpty) {
      _customMainnetRpc = url.trim();
      await prefs.setString(_customRpcKey, _customMainnetRpc!);
    } else {
      _customMainnetRpc = null;
      await prefs.remove(_customRpcKey);
    }
    _initClient();
    if (_keyPair != null) {
      await refreshBalance();
    }
    if (kDebugMode) {
      print('[OXSolana] RPC updated: $rpcUrl');
    }
  }

  Future<void> init() async {
    // Load custom RPC before initializing client
    final prefs = await SharedPreferences.getInstance();
    _customMainnetRpc = prefs.getString(_customRpcKey);
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

  /// Create a new Solana wallet from a fresh BIP39 mnemonic
  Future<String> createWallet() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Generate 12-word mnemonic and derive keypair from it
      _mnemonic = bip39.generateMnemonic();
      _keyPair = await Ed25519HDKeyPair.fromMnemonic(_mnemonic!);
      await _saveWallet();
      await refreshBalance();

      if (kDebugMode) {
        print('[OXSolana] Wallet created from mnemonic: $address');
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

  /// Export mnemonic for backup (user must have created wallet from mnemonic)
  String? exportMnemonic() => _mnemonic;

  /// Import wallet from mnemonic (BIP39)
  /// Validate a Solana address (Base58 + 32 bytes)
  static bool isValidSolanaAddress(String address) {
    if (address.length < 32 || address.length > 44) return false;
    try {
      Ed25519HDPublicKey.fromBase58(address);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validate a BIP39 mnemonic phrase
  static bool isValidMnemonic(String mnemonic) {
    final words = mnemonic.trim().split(RegExp(r'\s+'));
    if (words.length != 12 && words.length != 24) return false;
    return bip39.validateMnemonic(mnemonic.trim());
  }

  Future<String> importFromMnemonic(String mnemonic) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final trimmed = mnemonic.trim();

      // Validate mnemonic
      if (!isValidMnemonic(trimmed)) {
        throw Exception('Invalid mnemonic: must be 12 or 24 valid BIP39 words');
      }

      _mnemonic = trimmed;
      _keyPair = await Ed25519HDKeyPair.fromMnemonic(_mnemonic!);
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

  /// Refresh SOL balance and SPL token list
  Future<double> refreshBalance() async {
    if (_keyPair == null || _client == null) return 0;

    try {
      final lamports = await _client!.rpcClient.getBalance(address);
      _balance = lamports.value / lamportsPerSol;
      _error = null;
      notifyListeners();

      // Also refresh token list in background
      fetchTokens();

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

  /// Delete wallet — removes all key material from secure storage
  Future<void> deleteWallet() async {
    _keyPair = null;
    _mnemonic = null;
    _balance = 0;
    _tokens = [];
    _history = [];
    // Clear from all storage layers
    await _secureDelete(_keyStorageKey);
    await _secureDelete(_mnemonicStorageKey);
    notifyListeners();
  }

  // --- SPL Token support ---

  List<SplTokenInfo> _tokens = [];
  List<SplTokenInfo> get tokens => _tokens;

  bool _isLoadingTokens = false;
  bool get isLoadingTokens => _isLoadingTokens;

  /// Fetch all SPL token accounts owned by this wallet
  Future<List<SplTokenInfo>> fetchTokens() async {
    if (_keyPair == null || _client == null) return [];

    try {
      _isLoadingTokens = true;
      notifyListeners();

      final result = await _client!.rpcClient.getTokenAccountsByOwner(
        address,
        const TokenAccountsFilter.byProgramId(
          'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
        ),
        encoding: Encoding.jsonParsed,
      );

      final List<SplTokenInfo> tokenList = [];

      for (final account in result.value) {
        try {
          final data = account.account.data;
          if (data is ParsedAccountData) {
            final parsed = data.parsed as Map<String, dynamic>;
            final info = parsed['info'] as Map<String, dynamic>;
            final tokenAmount = info['tokenAmount'] as Map<String, dynamic>;

            final mint = info['mint'] as String;
            final rawAmount = tokenAmount['amount'] as String;
            final decimals = tokenAmount['decimals'] as int;
            final uiAmount = int.parse(rawAmount) / math.pow(10, decimals);

            // Skip zero-balance accounts
            if (uiAmount == 0) continue;

            // Lookup token metadata
            final meta = WellKnownTokens.lookup(mint, isDevnet: _isDevnet);

            tokenList.add(SplTokenInfo(
              mintAddress: mint,
              tokenAccountAddress: account.pubkey,
              balance: uiAmount,
              decimals: decimals,
              symbol: meta?.symbol ?? 'SPL',
              name: meta?.name ?? 'Unknown Token',
            ));
          }
        } catch (e) {
          if (kDebugMode) print('[OXSolana] Parse token error: $e');
        }
      }

      // Sort: known tokens first, then by balance
      tokenList.sort((a, b) {
        final aKnown = a.symbol != 'SPL' ? 0 : 1;
        final bKnown = b.symbol != 'SPL' ? 0 : 1;
        if (aKnown != bKnown) return aKnown.compareTo(bKnown);
        return b.balance.compareTo(a.balance);
      });

      _tokens = tokenList;
      _error = null;

      if (kDebugMode) {
        print('[OXSolana] Found ${tokenList.length} token accounts');
      }

      return tokenList;
    } catch (e) {
      if (kDebugMode) print('[OXSolana] Fetch tokens error: $e');
      _error = 'Failed to fetch tokens: $e';
      return _tokens;
    } finally {
      _isLoadingTokens = false;
      notifyListeners();
    }
  }

  /// Send SPL token
  Future<String> sendSplToken({
    required String mintAddress,
    required String toAddress,
    required double amount,
    required int decimals,
  }) async {
    if (_keyPair == null || _client == null) {
      throw Exception('Wallet not initialized');
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final rawAmount = (amount * math.pow(10, decimals)).toInt();

      final signature = await _client!.transferSplToken(
        mint: Ed25519HDPublicKey.fromBase58(mintAddress),
        destination: Ed25519HDPublicKey.fromBase58(toAddress),
        amount: rawAmount,
        owner: _keyPair!,
      );

      if (kDebugMode) {
        print('[OXSolana] SPL transfer: $signature');
      }

      await fetchTokens();
      return signature;
    } catch (e) {
      _error = 'SPL transfer failed: $e';
      if (kDebugMode) print('[OXSolana] $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Transaction History ---

  List<TransactionRecord> _history = [];
  List<TransactionRecord> get history => _history;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  /// Fetch recent transaction signatures, then resolve amounts in background
  Future<List<TransactionRecord>> fetchHistory({int limit = 20}) async {
    if (_keyPair == null || _client == null) return [];

    try {
      _isLoadingHistory = true;
      notifyListeners();

      final signatures = await _client!.rpcClient.getSignaturesForAddress(
        address,
        limit: limit,
      );

      _history = signatures.map((sig) => TransactionRecord(
        signature: sig.signature,
        slot: sig.slot,
        blockTime: sig.blockTime,
        isError: sig.err != null,
        memo: sig.memo,
        confirmationStatus: sig.confirmationStatus?.name,
      )).toList();

      _error = null;
      _isLoadingHistory = false;
      notifyListeners();

      if (kDebugMode) {
        print('[OXSolana] Fetched ${_history.length} transactions');
      }

      // Resolve amounts in background (don't block UI)
      _resolveTransactionAmounts();

      return _history;
    } catch (e) {
      if (kDebugMode) print('[OXSolana] Fetch history error: $e');
      _error = 'Failed to fetch history: $e';
      _isLoadingHistory = false;
      notifyListeners();
      return _history;
    }
  }

  /// Resolve SOL amounts for each transaction via getTransaction
  Future<void> _resolveTransactionAmounts() async {
    if (_client == null || _history.isEmpty) return;

    final myAddress = address;
    for (int i = 0; i < _history.length; i++) {
      final tx = _history[i];
      if (tx.solChange != null) continue; // already resolved
      if (tx.isError) continue; // skip failed

      try {
        final details = await _client!.rpcClient.getTransaction(
          tx.signature,
          encoding: Encoding.jsonParsed,
        );

        if (details?.meta != null) {
          final transaction = details!.transaction;
          List<String> pubkeys = [];

          if (transaction is sol_tx.ParsedTransaction) {
            pubkeys = transaction.message.accountKeys.map((k) => k.pubkey).toList();
          }

          // Find our account index
          int myIndex = pubkeys.indexOf(myAddress);

          if (myIndex >= 0 &&
              myIndex < details.meta!.preBalances.length &&
              myIndex < details.meta!.postBalances.length) {
            final pre = details.meta!.preBalances[myIndex];
            final post = details.meta!.postBalances[myIndex];
            final change = (post - pre) / lamportsPerSol;
            final fee = details.meta!.fee / lamportsPerSol;

            _history[i] = tx.withAmounts(solChange: change, fee: fee);
            notifyListeners(); // Update UI progressively
          }
        }
      } catch (e) {
        if (kDebugMode) print('[OXSolana] Resolve tx[$i] error: $e');
      }
    }
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

    // Private key → SecureStorage (Keychain on iOS/macOS, Keystore on Android)
    // Falls back to SharedPreferences on macOS debug builds without signing
    final keyBytes = await _keyPair!.extract();
    final encoded = base64Encode(keyBytes.bytes);
    await _secureWrite(_keyStorageKey, encoded);

    // Mnemonic → SecureStorage
    if (_mnemonic != null) {
      await _secureWrite(_mnemonicStorageKey, _mnemonic!);
    }
  }

  Future<void> _loadSavedWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDevnet = prefs.getBool(_networkKey) ?? false;

      // Load from SecureStorage (or fallback)
      String? encoded = await _secureRead(_keyStorageKey);
      _mnemonic = await _secureRead(_mnemonicStorageKey);

      if (encoded == null) return;

      final keyBytes = base64Decode(encoded);
      _keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: keyBytes,
      );

      if (kDebugMode) {
        print('[OXSolana] Wallet loaded: $address (mnemonic: ${_mnemonic != null ? "yes" : "no"}, secure: ✅)');
      }

      await refreshBalance();
    } catch (e) {
      if (kDebugMode) {
        print('[OXSolana] Failed to load saved wallet: $e');
      }
    }
  }
}
