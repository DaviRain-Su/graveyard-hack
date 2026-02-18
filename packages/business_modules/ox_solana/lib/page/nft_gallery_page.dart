import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';

import '../services/nft_service.dart';

/// NFT Gallery page — display wallet's NFT collection in a grid
class NftGalleryPage extends StatefulWidget {
  const NftGalleryPage({super.key});

  @override
  State<NftGalleryPage> createState() => _NftGalleryPageState();
}

class _NftGalleryPageState extends State<NftGalleryPage> {
  List<SolanaNft> _nfts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNfts();
  }

  Future<void> _loadNfts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      _nfts = await NftService.instance.fetchNfts();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: '🖼️ NFT Gallery',
        backgroundColor: ThemeColor.color190,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: ThemeColor.color100),
            onPressed: _loadNfts,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF9945FF)),
            SizedBox(height: 16),
            Text('Loading NFTs...', style: TextStyle(color: ThemeColor.color100)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😕', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('Error loading NFTs', style: TextStyle(color: ThemeColor.color0, fontSize: 16)),
              SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: ThemeColor.color110, fontSize: 12), textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNfts,
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF9945FF)),
                child: Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_nfts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🖼️', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('No NFTs Found', style: TextStyle(color: ThemeColor.color0, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('NFTs you own will appear here',
                style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
            SizedBox(height: 8),
            Text('Tip: Add a Helius API key in settings for\nbetter NFT metadata (free tier available)',
                style: TextStyle(color: ThemeColor.color110, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNfts,
      color: Color(0xFF9945FF),
      child: GridView.builder(
        padding: EdgeInsets.all(Adapt.px(12)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: Adapt.px(10),
          mainAxisSpacing: Adapt.px(10),
          childAspectRatio: 0.8,
        ),
        itemCount: _nfts.length,
        itemBuilder: (ctx, i) => _buildNftCard(_nfts[i]),
      ),
    );
  }

  Widget _buildNftCard(SolanaNft nft) {
    return GestureDetector(
      onTap: () => _showNftDetail(nft),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: nft.imageUrl != null
                    ? Image.network(
                        nft.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(nft),
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return _buildPlaceholder(nft, loading: true);
                        },
                      )
                    : _buildPlaceholder(nft),
              ),
            ),

            // Name + info
            Padding(
              padding: EdgeInsets.all(Adapt.px(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nft.name,
                    style: TextStyle(
                      color: ThemeColor.color0,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      if (nft.compressed)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          margin: EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF14F195).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('cNFT',
                              style: TextStyle(color: Color(0xFF14F195), fontSize: 9)),
                        ),
                      Expanded(
                        child: Text(
                          nft.collection ?? nft.shortMint,
                          style: TextStyle(color: ThemeColor.color110, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(SolanaNft nft, {bool loading = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF9945FF).withOpacity(0.3),
            Color(0xFF14F195).withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF9945FF)))
            : Text('🖼️', style: TextStyle(fontSize: 36)),
      ),
    );
  }

  void _showNftDetail(SolanaNft nft) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeColor.color100,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: nft.imageUrl != null
                    ? Image.network(
                        nft.imageUrl!,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(nft),
                      )
                    : SizedBox(
                        height: 200,
                        child: _buildPlaceholder(nft),
                      ),
              ),
              SizedBox(height: 16),

              // Name
              Text(nft.name,
                  style: TextStyle(color: ThemeColor.color0, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),

              // Collection
              if (nft.collection != null) ...[
                Row(
                  children: [
                    Icon(Icons.collections, size: 14, color: Color(0xFF9945FF)),
                    SizedBox(width: 4),
                    Text(nft.collection!,
                        style: TextStyle(color: Color(0xFF9945FF), fontSize: 13)),
                  ],
                ),
                SizedBox(height: 8),
              ],

              // Description
              if (nft.description.isNotEmpty) ...[
                Text(nft.description,
                    style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
                SizedBox(height: 12),
              ],

              // Attributes
              if (nft.attributes.isNotEmpty) ...[
                Text('Attributes',
                    style: TextStyle(color: ThemeColor.color0, fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: nft.attributes
                      .map((attr) => Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: ThemeColor.color180,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFF9945FF).withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(attr.trait.toUpperCase(),
                                    style: TextStyle(color: Color(0xFF9945FF), fontSize: 9, fontWeight: FontWeight.w600)),
                                Text(attr.value,
                                    style: TextStyle(color: ThemeColor.color0, fontSize: 12)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                SizedBox(height: 12),
              ],

              // Mint address
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeColor.color180,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text('Mint: ', style: TextStyle(color: ThemeColor.color100, fontSize: 12)),
                    Expanded(
                      child: Text(nft.mint,
                          style: TextStyle(color: ThemeColor.color0, fontSize: 11, fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        launchUrl(Uri.parse(nft.explorerUrl),
                            mode: LaunchMode.externalApplication);
                      },
                      icon: Icon(Icons.open_in_new, size: 16),
                      label: Text('Explorer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF9945FF),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
