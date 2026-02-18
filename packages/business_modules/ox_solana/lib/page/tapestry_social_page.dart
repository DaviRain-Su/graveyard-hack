import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatcore/chat-core.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';
import 'package:ox_common/navigator/navigator.dart';
import 'package:ox_module_service/ox_module_service.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/tapestry_service.dart';
import '../services/solana_wallet_service.dart';
import '../services/nft_service.dart';
import '../services/audius_service.dart';

/// Solana Social Hub — Bridge between Solana activities and 0xchat Nostr Moments
///
/// Instead of an isolated social page, this integrates Solana on-chain activities
/// with 0xchat's native Nostr-based Moments system:
/// - Share NFTs, transactions, music to Nostr Moments
/// - View recent Solana activity feed
/// - Tapestry on-chain social graph for cross-app discovery
class TapestrySocialPage extends StatefulWidget {
  const TapestrySocialPage({super.key});

  @override
  State<TapestrySocialPage> createState() => _TapestrySocialPageState();
}

class _TapestrySocialPageState extends State<TapestrySocialPage>
    with SingleTickerProviderStateMixin {
  final _walletService = SolanaWalletService.instance;
  final _tapestry = TapestryService.instance;
  late TabController _tabController;

  // Activity feed from local wallet history
  List<_SolanaActivity> _activities = [];
  bool _loadingActivities = true;

  // NFTs for sharing
  List<SolanaNft> _nfts = [];
  bool _loadingNfts = false;

  // Tapestry profiles (discover)
  List<TapestryProfile> _searchResults = [];
  bool _loadingSearch = false;
  final _searchController = TextEditingController();

  // Settings
  bool _autoShareTx = false;
  bool _autoShareNft = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadActivities();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Load from tapestry service local settings
    setState(() {
      _autoShareTx = _tapestry.localBindings.containsKey('auto_share_tx');
      _autoShareNft = _tapestry.localBindings.containsKey('auto_share_nft');
    });
  }

  Future<void> _loadActivities() async {
    setState(() => _loadingActivities = true);
    try {
      final activities = <_SolanaActivity>[];

      // Add wallet balance as first activity
      if (_walletService.hasWallet) {
        activities.add(_SolanaActivity(
          type: _ActivityType.transaction,
          title: 'Wallet Balance',
          subtitle: _walletService.address.isNotEmpty
              ? '${_walletService.address.substring(0, 8)}...'
              : 'Unknown',
          amount: _walletService.balance.toStringAsFixed(4),
          shared: false,
        ));
      }

      // Add NFTs as shareable activities
      try {
        final nfts = await NftService.instance.fetchNfts(
            ownerAddress: _walletService.address);
        _nfts = nfts;
        for (final nft in nfts.take(10)) {
          activities.add(_SolanaActivity(
            type: _ActivityType.nft,
            title: nft.name,
            subtitle: nft.collection ?? 'Unknown Collection',
            imageUrl: nft.imageUrl,
            metadata: {
              'name': nft.name,
              'collection': {'name': nft.collection ?? ''},
              'mint': nft.mint,
              'image': nft.imageUrl ?? '',
            },
            shared: false,
          ));
        }
      } catch (_) {}

      _activities = activities;
    } catch (_) {}
    if (mounted) setState(() => _loadingActivities = false);
  }

  // ── Share to Nostr Moments ──

  Future<void> _shareToMoments(String content, {String? imageUrl}) async {
    OXLoading.show();
    try {
      // Use 0xchat's native Moment system (Nostr NIP-01 note)
      final event = await Moment.sharedInstance.sendPublicNote(
        content,
        hashTags: ['solana', '0xchat'],
      );
      OXLoading.dismiss();

      if (event.status && mounted) {
        CommonToast.instance.show(context, 'Shared to Moments! 🎉');
      } else if (mounted) {
        CommonToast.instance.show(context, 'Failed to share: ${event.message}');
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) CommonToast.instance.show(context, 'Error: $e');
    }

    // Also share to Tapestry if connected
    if (_tapestry.hasApiKey && _tapestry.profileId != null) {
      try {
        await _tapestry.createContent(
          contentId: '0xchat_${DateTime.now().millisecondsSinceEpoch}',
          text: content,
        );
      } catch (_) {}
    }
  }

  Future<void> _shareNftToMoments(Map<String, dynamic> nft) async {
    final name = nft['name'] ?? 'NFT';
    final collection = nft['collection']?['name'] ?? '';
    final mint = nft['mint'] ?? nft['id'] ?? '';
    final imageUrl = nft['image'] ?? nft['cached_image_uri'] ?? '';

    final content = '🖼️ Check out my NFT: $name\n'
        '${collection.isNotEmpty ? '📦 Collection: $collection\n' : ''}'
        '${imageUrl.isNotEmpty ? '$imageUrl\n' : ''}'
        '🔗 Solana NFT${mint.toString().isNotEmpty ? ' • ${mint.toString().substring(0, 8)}...' : ''}\n'
        '#solana #nft #0xchat';

    await _shareToMoments(content, imageUrl: imageUrl);
  }

  Future<void> _shareTxToMoments(Map<String, dynamic> tx) async {
    final type = tx['type'] ?? 'transfer';
    final amount = tx['amount'] ?? '?';
    final sig = tx['signature']?.toString() ?? '';

    final content = '💸 $type $amount SOL on Solana\n'
        '${sig.isNotEmpty ? '🔗 tx: ${sig.substring(0, 16)}...\n' : ''}'
        '#solana #defi #0xchat';

    await _shareToMoments(content);
  }

  Future<void> _shareMusicToMoments(String title, String artist, String shareUrl) async {
    final content = '🎵 Listening to "$title" by $artist on Audius\n'
        '🔗 $shareUrl\n'
        '#music #audius #solana #0xchat';

    await _shareToMoments(content);
  }

  void _showComposeSheet() {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Share to Moments',
                    style: TextStyle(
                        color: ThemeColor.color0,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: ThemeColor.color110),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: textController,
              style: TextStyle(color: ThemeColor.color0, fontSize: 15),
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Share your Solana experience...\n\n#solana #0xchat',
                hintStyle: TextStyle(color: ThemeColor.color110),
                filled: true,
                fillColor: ThemeColor.color180,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 12),

            // Quick-attach buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAttachChip('🖼️ NFT', () {
                    Navigator.pop(ctx);
                    _showNftPicker(textController.text);
                  }),
                  SizedBox(width: 8),
                  _buildAttachChip('💰 Wallet', () {
                    final addr = _walletService.address;
                    if (addr.isNotEmpty) {
                      textController.text += '\n💰 ${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
                    }
                  }),
                  SizedBox(width: 8),
                  _buildAttachChip('🎵 Music', () {
                    Navigator.pop(ctx);
                    _showMusicPicker(textController.text);
                  }),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Send button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(ctx);
                  _shareToMoments(text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Post to Nostr Moments',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeColor.color160),
        ),
        child: Text(label,
            style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
      ),
    );
  }

  void _showNftPicker(String existingText) {
    if (_nfts.isEmpty) {
      CommonToast.instance.show(context, 'No NFTs found in wallet');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: 400,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick an NFT to share',
                style: TextStyle(
                    color: ThemeColor.color0,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _nfts.length,
                itemBuilder: (_, i) {
                  final nft = _nfts[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: nft.imageUrl != null
                          ? Image.network(nft.imageUrl!, width: 44, height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _nftPlaceholder())
                          : _nftPlaceholder(),
                    ),
                    title: Text(nft.name,
                        style: TextStyle(color: ThemeColor.color0)),
                    subtitle: Text(
                        nft.collection ?? '',
                        style: TextStyle(
                            color: ThemeColor.color110, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareNftToMoments({
                        'name': nft.name,
                        'collection': {'name': nft.collection ?? ''},
                        'mint': nft.mint,
                        'image': nft.imageUrl ?? '',
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nftPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      color: ThemeColor.color170,
      child: Icon(Icons.image, color: ThemeColor.color110),
    );
  }

  void _showMusicPicker(String existingText) async {
    OXLoading.show();
    final tracks = await AudiusService.instance.getTrending(limit: 10);
    OXLoading.dismiss();
    if (tracks.isEmpty || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: 400,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a track to share',
                style: TextStyle(
                    color: ThemeColor.color0,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (_, i) {
                  final t = tracks[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: t.artworkUrl != null
                          ? Image.network(t.artworkUrl!, width: 40, height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                    width: 40,
                                    height: 40,
                                    color: ThemeColor.color170,
                                    child: Icon(Icons.music_note,
                                        color: ThemeColor.color110, size: 18),
                                  ))
                          : Container(
                              width: 40,
                              height: 40,
                              color: ThemeColor.color170,
                              child: Icon(Icons.music_note,
                                  color: ThemeColor.color110, size: 18)),
                    ),
                    title: Text(t.title,
                        style: TextStyle(color: ThemeColor.color0, fontSize: 14)),
                    subtitle: Text(t.artistName,
                        style: TextStyle(
                            color: ThemeColor.color110, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareMusicToMoments(t.title, t.artistName, t.shareUrl);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tapestry discover ──

  Future<void> _searchTapestry() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || !_tapestry.hasApiKey) return;

    setState(() => _loadingSearch = true);
    try {
      _searchResults = await _tapestry.searchProfiles(query);
    } catch (_) {}
    if (mounted) setState(() => _loadingSearch = false);
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: 'Solana Social',
        backgroundColor: ThemeColor.color190,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF6366F1),
        child: Icon(Icons.edit, color: Colors.white),
        onPressed: _showComposeSheet,
      ),
      body: Column(
        children: [
          // Profile summary card
          _buildProfileSummary(),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Color(0xFF6366F1),
            unselectedLabelColor: ThemeColor.color100,
            indicatorColor: Color(0xFF6366F1),
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: '📋 Activity'),
              Tab(text: '🔍 Discover'),
              Tab(text: '⚙️ Settings'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActivityTab(),
                _buildDiscoverTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary() {
    final addr = _walletService.address;
    final shortAddr = addr.isNotEmpty
        ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}'
        : 'No wallet';

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6366F1).withOpacity(0.15),
            Color(0xFF9945FF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF9945FF)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.account_circle, color: Colors.white, size: 28),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solana Social Hub',
                  style: TextStyle(
                      color: ThemeColor.color0,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(shortAddr,
                    style: TextStyle(
                        color: ThemeColor.color100,
                        fontSize: 12,
                        fontFamily: 'monospace')),
                SizedBox(height: 4),
                Row(
                  children: [
                    _buildBadge('Nostr Moments', Color(0xFF9945FF)),
                    SizedBox(width: 6),
                    if (_tapestry.hasApiKey)
                      _buildBadge('Tapestry ✓', Color(0xFF14F195)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  // ── Activity Tab ──

  Widget _buildActivityTab() {
    if (_loadingActivities) {
      return Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rocket_launch, size: 64, color: ThemeColor.color110),
            SizedBox(height: 16),
            Text('No Solana activity yet',
                style: TextStyle(color: ThemeColor.color100, fontSize: 16)),
            SizedBox(height: 8),
            Text('Send SOL, collect NFTs, or listen to music\nto see activities here',
                style: TextStyle(color: ThemeColor.color110, fontSize: 13),
                textAlign: TextAlign.center),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showComposeSheet,
              icon: Icon(Icons.edit, size: 16),
              label: Text('Write a Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      color: Color(0xFF6366F1),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _activities.length,
        itemBuilder: (_, i) => _buildActivityCard(_activities[i]),
      ),
    );
  }

  Widget _buildActivityCard(_SolanaActivity activity) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon / image
          if (activity.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                activity.imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _activityIcon(activity.type),
              ),
            )
          else
            _activityIcon(activity.type),

          SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: TextStyle(
                        color: ThemeColor.color0,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 2),
                Text(activity.subtitle,
                    style: TextStyle(
                        color: ThemeColor.color110, fontSize: 12)),
                if (activity.amount != null) ...[
                  SizedBox(height: 4),
                  Text('${activity.amount} SOL',
                      style: TextStyle(
                          color: Color(0xFF14F195),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),

          // Share button
          GestureDetector(
            onTap: () {
              if (activity.type == _ActivityType.nft && activity.metadata != null) {
                _shareNftToMoments(activity.metadata!);
              } else if (activity.type == _ActivityType.transaction &&
                  activity.metadata != null) {
                _shareTxToMoments(activity.metadata!);
              } else {
                _shareToMoments('${activity.title}\n${activity.subtitle}\n#solana #0xchat');
              }
            },
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.share, size: 18, color: Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityIcon(_ActivityType type) {
    IconData icon;
    Color color;
    switch (type) {
      case _ActivityType.transaction:
        icon = Icons.swap_horiz;
        color = Color(0xFF14F195);
        break;
      case _ActivityType.nft:
        icon = Icons.image;
        color = Color(0xFF9945FF);
        break;
      case _ActivityType.music:
        icon = Icons.music_note;
        color = Color(0xFFEC4899);
        break;
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  // ── Discover Tab ──

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: ThemeColor.color0),
            decoration: InputDecoration(
              hintText: _tapestry.hasApiKey
                  ? 'Search Solana users on Tapestry...'
                  : 'Connect Tapestry API key to discover users',
              hintStyle: TextStyle(color: ThemeColor.color110, fontSize: 14),
              filled: true,
              fillColor: ThemeColor.color180,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: ThemeColor.color100),
              suffixIcon: _loadingSearch
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF6366F1))),
                    )
                  : IconButton(
                      icon: Icon(Icons.search, color: Color(0xFF6366F1)),
                      onPressed: _searchTapestry,
                    ),
            ),
            enabled: _tapestry.hasApiKey,
            onSubmitted: (_) => _searchTapestry(),
          ),
        ),

        // Info card when no API key
        if (!_tapestry.hasApiKey)
          _buildTapestryInfoCard(),

        // Results
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore, size: 60, color: ThemeColor.color110),
                      SizedBox(height: 16),
                      Text('Discover Solana Users',
                          style: TextStyle(
                              color: ThemeColor.color100, fontSize: 16)),
                      SizedBox(height: 4),
                      Text(
                          _tapestry.hasApiKey
                              ? 'Search by username or wallet address'
                              : 'Add Tapestry API key in Settings',
                          style: TextStyle(
                              color: ThemeColor.color110, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) =>
                      _buildProfileItem(_searchResults[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildTapestryInfoCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFF6366F1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub, color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 8),
              Text('Tapestry Social Graph',
                  style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Tapestry is an on-chain social graph on Solana.\n'
            'Add your API key in Settings to discover users\n'
            'and follow them across all Tapestry-integrated apps.',
            style: TextStyle(color: ThemeColor.color100, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(TapestryProfile profile) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF9945FF)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (profile.username ?? '?')[0].toUpperCase(),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.username ?? 'Unknown',
                    style: TextStyle(
                        color: ThemeColor.color0,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (profile.bio != null)
                  Text(profile.bio!,
                      style: TextStyle(color: ThemeColor.color100, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (profile.walletAddress != null)
                  Text(
                    '${profile.walletAddress!.substring(0, 6)}...${profile.walletAddress!.substring(profile.walletAddress!.length - 4)}',
                    style: TextStyle(
                        color: ThemeColor.color110,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
              ],
            ),
          ),
          // Follow on Tapestry
          if (profile.id != null && profile.id != _tapestry.profileId)
            GestureDetector(
              onTap: () async {
                final isFollowing =
                    _tapestry.isFollowingCached(profile.id!);
                bool ok;
                if (isFollowing) {
                  ok = await _tapestry.unfollowUser(profile.id!);
                } else {
                  ok = await _tapestry.followUser(profile.id!);
                }
                if (ok && mounted) {
                  setState(() {});
                  CommonToast.instance.show(context,
                      isFollowing ? 'Unfollowed' : 'Following! ✅');
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _tapestry.isFollowingCached(profile.id!)
                      ? ThemeColor.color170
                      : Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _tapestry.isFollowingCached(profile.id!)
                      ? 'Following'
                      : 'Follow',
                  style: TextStyle(
                    color: _tapestry.isFollowingCached(profile.id!)
                        ? ThemeColor.color100
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Settings Tab ──

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share Settings',
              style: TextStyle(
                  color: ThemeColor.color0,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Choose what gets shared to Nostr Moments',
              style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
          SizedBox(height: 16),

          _buildSettingTile(
            icon: Icons.swap_horiz,
            title: 'Auto-share Transactions',
            subtitle: 'Post SOL transfers to Moments automatically',
            value: _autoShareTx,
            onChanged: (v) async {
              setState(() => _autoShareTx = v);
              if (v) {
                await _tapestry.bindLocal(
                    nostrPubkey: 'auto_share_tx', solanaAddress: 'true');
              } else {
                await _tapestry.unbindLocal('auto_share_tx');
              }
            },
          ),

          _buildSettingTile(
            icon: Icons.image,
            title: 'Auto-share NFTs',
            subtitle: 'Post new NFT acquisitions to Moments',
            value: _autoShareNft,
            onChanged: (v) async {
              setState(() => _autoShareNft = v);
              if (v) {
                await _tapestry.bindLocal(
                    nostrPubkey: 'auto_share_nft', solanaAddress: 'true');
              } else {
                await _tapestry.unbindLocal('auto_share_nft');
              }
            },
          ),

          SizedBox(height: 24),

          // Tapestry API Key
          Text('Tapestry Integration',
              style: TextStyle(
                  color: ThemeColor.color0,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Connect to Tapestry for cross-app social discovery',
              style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
          SizedBox(height: 12),

          _buildApiKeySection(),

          SizedBox(height: 24),

          // How it works
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThemeColor.color180,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How it works',
                    style: TextStyle(
                        color: ThemeColor.color0,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                _buildHowItWorksRow('1️⃣',
                    'Solana activities (TX, NFT, music) appear in Activity tab'),
                _buildHowItWorksRow(
                    '2️⃣', 'Tap share button → posts to 0xchat Nostr Moments'),
                _buildHowItWorksRow('3️⃣',
                    'Your contacts see it in their Moments feed'),
                _buildHowItWorksRow('4️⃣',
                    'Tapestry lets users across apps discover you on Solana'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFF6366F1).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Color(0xFF6366F1), size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: ThemeColor.color0,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: TextStyle(
                        color: ThemeColor.color110, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Color(0xFF6366F1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeySection() {
    if (_tapestry.hasApiKey) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF14F195).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF14F195).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF14F195), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tapestry Connected',
                      style: TextStyle(
                          color: Color(0xFF14F195),
                          fontWeight: FontWeight.w600)),
                  if (_tapestry.profileId != null)
                    Text('Profile: ${_tapestry.profileId}',
                        style: TextStyle(
                            color: ThemeColor.color110, fontSize: 11)),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await _tapestry.setApiKey(null);
                if (mounted) setState(() {});
              },
              child: Text('Disconnect',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final keyController = TextEditingController();
    return Column(
      children: [
        TextField(
          controller: keyController,
          style: TextStyle(color: ThemeColor.color0),
          decoration: InputDecoration(
            hintText: 'Enter Tapestry API key',
            hintStyle: TextStyle(color: ThemeColor.color110),
            filled: true,
            fillColor: ThemeColor.color180,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(Icons.vpn_key, color: Color(0xFF6366F1)),
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final key = keyController.text.trim();
                  if (key.isEmpty) return;
                  await _tapestry.setApiKey(key);
                  if (mounted) {
                    setState(() {});
                    CommonToast.instance.show(context, 'Connected! ✅');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6366F1),
                ),
                child: Text('Connect',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(width: 8),
            TextButton(
              onPressed: () {
                launchUrl(
                    Uri.parse('https://app.usetapestry.dev'),
                    mode: LaunchMode.externalApplication);
              },
              child: Text('Get key →',
                  style: TextStyle(color: Color(0xFF6366F1), fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHowItWorksRow(String num, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num, style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: ThemeColor.color100, fontSize: 12, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

// ── Activity model ──

enum _ActivityType { transaction, nft, music }

class _SolanaActivity {
  final _ActivityType type;
  final String title;
  final String subtitle;
  final String? amount;
  final String? imageUrl;
  final DateTime? timestamp;
  final Map<String, dynamic>? metadata;
  final bool shared;

  _SolanaActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    this.amount,
    this.imageUrl,
    this.timestamp,
    this.metadata,
    this.shared = false,
  });
}
