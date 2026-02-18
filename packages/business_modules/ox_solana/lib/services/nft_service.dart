import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'solana_wallet_service.dart';

/// NFT service — fetch and display NFTs from Solana wallet.
///
/// Uses Metaplex DAS (Digital Asset Standard) API for NFT metadata.
/// Fallback: direct RPC getProgramAccounts with Metaplex Token Metadata program.
class NftService {
  static final NftService instance = NftService._();
  NftService._();

  List<SolanaNft> _nfts = [];
  List<SolanaNft> get nfts => List.unmodifiable(_nfts);
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Helius DAS API (free tier: 100 req/sec)
  /// Set via env or settings for power users
  String? _heliusApiKey;
  void setHeliusApiKey(String key) => _heliusApiKey = key;

  /// Fetch NFTs for current wallet
  Future<List<SolanaNft>> fetchNfts({String? ownerAddress}) async {
    final address = ownerAddress ?? SolanaWalletService.instance.address;
    if (address.isEmpty) return [];

    _isLoading = true;

    try {
      // Try Helius DAS API first (most reliable)
      if (_heliusApiKey != null && _heliusApiKey!.isNotEmpty) {
        _nfts = await _fetchViaHelius(address);
      } else {
        // Fallback: use public RPC getTokenAccountsByOwner + filter NFTs
        _nfts = await _fetchViaRpc(address);
      }

      if (kDebugMode) print('[NFT] Fetched ${_nfts.length} NFTs for ${address.substring(0, 8)}...');
    } catch (e) {
      if (kDebugMode) print('[NFT] Fetch error: $e');
    } finally {
      _isLoading = false;
    }

    return _nfts;
  }

  /// Fetch via Helius DAS API (preferred)
  Future<List<SolanaNft>> _fetchViaHelius(String owner) async {
    final url = 'https://mainnet.helius-rpc.com/?api-key=$_heliusApiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 'nft-fetch',
        'method': 'getAssetsByOwner',
        'params': {
          'ownerAddress': owner,
          'page': 1,
          'limit': 50,
          'displayOptions': {
            'showFungible': false,
            'showNativeBalance': false,
          },
        },
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = (data['result']?['items'] as List?) ?? [];
      return items
          .map((item) => SolanaNft.fromDas(item))
          .where((nft) => nft.name.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Fetch via standard RPC — find token accounts with amount=1, decimals=0 (NFT pattern)
  Future<List<SolanaNft>> _fetchViaRpc(String owner) async {
    final wallet = SolanaWalletService.instance;
    final rpcUrl = wallet.rpcUrl;

    try {
      // Get all token accounts
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            owner,
            {'programId': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'},
            {'encoding': 'jsonParsed'},
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final accounts = (data['result']?['value'] as List?) ?? [];

      final nftMints = <String>[];
      for (final account in accounts) {
        final info = account['account']?['data']?['parsed']?['info'];
        if (info == null) continue;

        final amount = info['tokenAmount']?['uiAmount'] ?? 0;
        final decimals = info['tokenAmount']?['decimals'] ?? 0;

        // NFT pattern: amount = 1, decimals = 0
        if (amount == 1 && decimals == 0) {
          final mint = info['mint'];
          if (mint != null) nftMints.add(mint);
        }
      }

      if (nftMints.isEmpty) return [];

      // Fetch metadata for each mint (batch, limit to 20)
      final nfts = <SolanaNft>[];
      for (final mint in nftMints.take(20)) {
        final nft = await _fetchNftMetadata(mint, rpcUrl);
        if (nft != null) nfts.add(nft);
      }

      return nfts;
    } catch (e) {
      if (kDebugMode) print('[NFT] RPC fetch error: $e');
      return [];
    }
  }

  /// Fetch NFT metadata from Metaplex Token Metadata program
  Future<SolanaNft?> _fetchNftMetadata(String mint, String rpcUrl) async {
    try {
      // Derive metadata PDA
      // Metaplex Token Metadata Program: metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s
      // PDA: ["metadata", program_id, mint]
      // For simplicity, create a basic NFT entry from mint
      return SolanaNft(
        mint: mint,
        name: 'NFT #${mint.substring(0, 6)}',
        symbol: 'NFT',
        description: '',
        imageUrl: null,
        collection: null,
        attributes: [],
      );
    } catch (e) {
      return null;
    }
  }

  /// Try to fetch off-chain metadata from URI
  static Future<Map<String, dynamic>?> fetchOffChainMetadata(String uri) async {
    try {
      // Handle IPFS URIs
      String url = uri;
      if (uri.startsWith('ipfs://')) {
        url = 'https://ipfs.io/ipfs/${uri.substring(7)}';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('[NFT] Off-chain metadata error: $e');
    }
    return null;
  }
}

/// Solana NFT model
class SolanaNft {
  final String mint;
  final String name;
  final String symbol;
  final String description;
  final String? imageUrl;
  final String? collection;
  final List<NftAttribute> attributes;
  final String? externalUrl;
  final String? animationUrl;
  final bool compressed;

  SolanaNft({
    required this.mint,
    required this.name,
    this.symbol = '',
    this.description = '',
    this.imageUrl,
    this.collection,
    this.attributes = const [],
    this.externalUrl,
    this.animationUrl,
    this.compressed = false,
  });

  String get shortMint => '${mint.substring(0, 4)}...${mint.substring(mint.length - 4)}';

  String get explorerUrl {
    final cluster = SolanaWalletService.instance.isDevnet ? '?cluster=devnet' : '';
    return 'https://explorer.solana.com/address/$mint$cluster';
  }

  /// Parse from Helius DAS API response
  factory SolanaNft.fromDas(Map<String, dynamic> json) {
    final content = json['content'] ?? {};
    final metadata = content['metadata'] ?? {};
    final files = (content['files'] as List?) ?? [];
    final links = content['links'] ?? {};

    String? imageUrl = links['image'] ?? content['json_uri'];
    if (imageUrl != null && imageUrl.startsWith('ipfs://')) {
      imageUrl = 'https://ipfs.io/ipfs/${imageUrl.substring(7)}';
    }

    // Try to get image from files
    if (imageUrl == null && files.isNotEmpty) {
      for (final f in files) {
        final mime = f['mime'] ?? '';
        if (mime.toString().startsWith('image/')) {
          imageUrl = f['uri'];
          break;
        }
      }
    }

    final attrs = (metadata['attributes'] as List?)
            ?.map((a) => NftAttribute(
                  trait: a['trait_type']?.toString() ?? '',
                  value: a['value']?.toString() ?? '',
                ))
            .toList() ??
        [];

    return SolanaNft(
      mint: json['id'] ?? '',
      name: metadata['name'] ?? content['name'] ?? 'Unnamed NFT',
      symbol: metadata['symbol'] ?? '',
      description: metadata['description'] ?? '',
      imageUrl: imageUrl,
      collection: json['grouping']?.isNotEmpty == true
          ? json['grouping'][0]['group_value']
          : null,
      attributes: attrs,
      externalUrl: links['external_url'],
      animationUrl: links['animation_url'],
      compressed: json['compression']?['compressed'] == true,
    );
  }

  /// Chat share payload
  Map<String, dynamic> toSharePayload() => {
        'type': 'solana_nft',
        'mint': mint,
        'name': name,
        'symbol': symbol,
        if (imageUrl != null) 'image_url': imageUrl,
        if (collection != null) 'collection': collection,
      };
}

class NftAttribute {
  final String trait;
  final String value;
  const NftAttribute({required this.trait, required this.value});
}
