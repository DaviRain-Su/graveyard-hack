import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';

import '../services/tapestry_service.dart';
import '../services/solana_wallet_service.dart';

/// Tapestry Social Page — On-chain social graph (follows, content, likes, comments)
class TapestrySocialPage extends StatefulWidget {
  const TapestrySocialPage({super.key});

  @override
  State<TapestrySocialPage> createState() => _TapestrySocialPageState();
}

class _TapestrySocialPageState extends State<TapestrySocialPage> with SingleTickerProviderStateMixin {
  final _tapestry = TapestryService.instance;
  final _walletService = SolanaWalletService.instance;
  late TabController _tabController;

  List<TapestryContent> _feedItems = [];
  List<TapestryProfile> _followers = [];
  List<TapestryProfile> _following = [];
  List<TapestryProfile> _searchResults = [];

  bool _loadingFeed = false;
  bool _loadingFollowers = false;
  bool _loadingFollowing = false;
  bool _loadingSearch = false;

  final _searchController = TextEditingController();
  final _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_tapestry.hasApiKey) return;

    // Load feed + social counts in parallel
    await Future.wait([
      _loadFeed(),
      _tapestry.refreshSocialCounts(),
    ]);
  }

  Future<void> _loadFeed() async {
    if (_tapestry.profileId == null) return;
    setState(() => _loadingFeed = true);
    try {
      _feedItems = await _tapestry.getUserContent(_tapestry.profileId!);
    } catch (_) {}
    if (mounted) setState(() => _loadingFeed = false);
  }

  Future<void> _loadFollowers() async {
    setState(() => _loadingFollowers = true);
    try {
      _followers = await _tapestry.getFollowers();
    } catch (_) {}
    if (mounted) setState(() => _loadingFollowers = false);
  }

  Future<void> _loadFollowing() async {
    setState(() => _loadingFollowing = true);
    try {
      _following = await _tapestry.getFollowing();
    } catch (_) {}
    if (mounted) setState(() => _loadingFollowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: 'Tapestry Social',
        backgroundColor: ThemeColor.color190,
      ),
      body: !_tapestry.hasApiKey
          ? _buildSetupView()
          : _tapestry.profileId == null
              ? _buildCreateProfileView()
              : _buildSocialView(),
    );
  }

  // ── Setup view (no API key) ──
  Widget _buildSetupView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Adapt.px(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTapestryLogo(),
            SizedBox(height: Adapt.px(24)),
            Text('Connect to Tapestry',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ThemeColor.color0)),
            SizedBox(height: 8),
            Text(
              'Tapestry is an on-chain social graph protocol on Solana.\n'
              'Connect to follow users, share content, and build your social presence.',
              style: TextStyle(color: ThemeColor.color100, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            _buildFeatureChip('👥 Follow/Unfollow users on-chain'),
            _buildFeatureChip('📝 Post & share content'),
            _buildFeatureChip('❤️ Like & comment on posts'),
            _buildFeatureChip('🔍 Discover users across apps'),
            _buildFeatureChip('🔗 Cross-app social graph'),
            SizedBox(height: Adapt.px(32)),
            _buildApiKeyInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTapestryLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Icon(Icons.hub, color: Colors.white, size: 40),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildApiKeyInput() {
    final controller = TextEditingController(text: _tapestry.hasApiKey ? '••••••••' : '');
    return Column(
      children: [
        TextField(
          controller: controller,
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
        SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final key = controller.text.trim();
            if (key.isEmpty || key == '••••••••') {
              CommonToast.instance.show(context, 'Please enter API key');
              return;
            }
            await _tapestry.setApiKey(key);
            if (mounted) setState(() {});
            CommonToast.instance.show(context, 'API key saved! ✅');
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('Connect Tapestry',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            // Open Tapestry dashboard
            CommonToast.instance.show(context, 'Get your API key at app.usetapestry.dev');
          },
          child: Text('Get free API key →',
              style: TextStyle(color: Color(0xFF6366F1), fontSize: 13)),
        ),
      ],
    );
  }

  // ── Create profile view ──
  Widget _buildCreateProfileView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Adapt.px(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTapestryLogo(),
            SizedBox(height: 24),
            Text('Create Your Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ThemeColor.color0)),
            SizedBox(height: 8),
            Text('Join the on-chain social graph',
                style: TextStyle(color: ThemeColor.color100, fontSize: 14)),
            SizedBox(height: 32),
            GestureDetector(
              onTap: _createProfile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('Create Profile on Tapestry',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProfile() async {
    final address = _walletService.address;
    if (address.isEmpty) {
      CommonToast.instance.show(context, 'Create a Solana wallet first');
      return;
    }

    OXLoading.show();
    try {
      await _tapestry.findOrCreateProfile(
        walletAddress: address,
        username: 'oxchat_${address.substring(0, 8)}',
        bio: '0xchat user on Solana',
        nostrPubkey: _walletService.nostrPubkey,
      );
      OXLoading.dismiss();
      if (mounted) {
        setState(() {});
        CommonToast.instance.show(context, 'Profile created! 🎉');
        _loadData();
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) CommonToast.instance.show(context, 'Error: $e');
    }
  }

  // ── Social view (logged in) ──
  Widget _buildSocialView() {
    return Column(
      children: [
        // Profile card
        _buildProfileCard(),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: Color(0xFF6366F1),
          unselectedLabelColor: ThemeColor.color100,
          indicatorColor: Color(0xFF6366F1),
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Feed'),
            Tab(text: 'Discover'),
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
          onTap: (index) {
            if (index == 2 && _followers.isEmpty) _loadFollowers();
            if (index == 3 && _following.isEmpty) _loadFollowing();
          },
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFeedTab(),
              _buildDiscoverTab(),
              _buildFollowersTab(),
              _buildFollowingTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return ListenableBuilder(
      listenable: _tapestry,
      builder: (_, __) {
        final profile = _tapestry.profile;
        return Container(
          margin: EdgeInsets.all(Adapt.px(16)),
          padding: EdgeInsets.all(Adapt.px(16)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1).withOpacity(0.15), Color(0xFFA855F7).withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF6366F1).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (profile?.username ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.username ?? 'Unknown',
                      style: TextStyle(color: ThemeColor.color0, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (profile?.bio != null)
                      Text(profile!.bio!,
                          style: TextStyle(color: ThemeColor.color100, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        _buildCountChip('${_tapestry.followersCount}', 'Followers'),
                        SizedBox(width: 16),
                        _buildCountChip('${_tapestry.followingCount}', 'Following'),
                      ],
                    ),
                  ],
                ),
              ),

              // Edit profile
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Color(0xFF6366F1), size: 20),
                onPressed: _showEditProfileDialog,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountChip(String count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count,
            style: TextStyle(color: ThemeColor.color0, fontSize: 14, fontWeight: FontWeight.bold)),
        SizedBox(width: 3),
        Text(label, style: TextStyle(color: ThemeColor.color100, fontSize: 11)),
      ],
    );
  }

  // ── Feed tab ──
  Widget _buildFeedTab() {
    return Column(
      children: [
        // Post composer
        _buildPostComposer(),

        // Feed list
        Expanded(
          child: _loadingFeed
              ? Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _feedItems.isEmpty
                  ? _buildEmptyFeed()
                  : RefreshIndicator(
                      onRefresh: _loadFeed,
                      color: Color(0xFF6366F1),
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: Adapt.px(16)),
                        itemCount: _feedItems.length,
                        itemBuilder: (_, i) => _buildContentCard(_feedItems[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPostComposer() {
    return Container(
      margin: EdgeInsets.fromLTRB(Adapt.px(16), Adapt.px(12), Adapt.px(16), Adapt.px(8)),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _postController,
              style: TextStyle(color: ThemeColor.color0, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Share something on-chain...',
                hintStyle: TextStyle(color: ThemeColor.color110, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _submitPost,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    OXLoading.show();
    try {
      final content = await _tapestry.createContent(
        contentType: 'text_post',
        text: text,
      );
      OXLoading.dismiss();
      if (content != null) {
        _postController.clear();
        _feedItems.insert(0, content);
        if (mounted) setState(() {});
        CommonToast.instance.show(context, 'Posted on-chain! 🎉');
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) CommonToast.instance.show(context, 'Error: $e');
    }
  }

  Widget _buildEmptyFeed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed_outlined, size: 60, color: ThemeColor.color110),
          SizedBox(height: 16),
          Text('No posts yet', style: TextStyle(color: ThemeColor.color100, fontSize: 16)),
          SizedBox(height: 4),
          Text('Share your first on-chain content!',
              style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildContentCard(TapestryContent content) {
    final typeIcon = _contentTypeIcon(content.contentType);
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge + time
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 12, color: Color(0xFF6366F1)),
                    SizedBox(width: 4),
                    Text(content.contentType ?? 'post',
                        style: TextStyle(color: Color(0xFF6366F1), fontSize: 11)),
                  ],
                ),
              ),
              Spacer(),
              if (content.createdAt != null)
                Text(_timeAgo(content.createdAt!),
                    style: TextStyle(color: ThemeColor.color110, fontSize: 11)),
            ],
          ),
          SizedBox(height: 10),

          // Content text
          Text(content.text ?? '',
              style: TextStyle(color: ThemeColor.color0, fontSize: 14, height: 1.4)),

          // Metadata (if transaction)
          if (content.contentType == 'transaction' && content.properties['signature'] != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeColor.color190,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, size: 14, color: Color(0xFF14F195)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'tx: ${content.properties['signature'].toString().substring(0, 16)}...',
                      style: TextStyle(color: ThemeColor.color100, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Like/Comment buttons
          SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (content.id != null) {
                    await _tapestry.likeContent(content.id!);
                    CommonToast.instance.show(context, 'Liked! ❤️');
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 16, color: ThemeColor.color100),
                    SizedBox(width: 4),
                    Text('${content.likeCount}',
                        style: TextStyle(color: ThemeColor.color100, fontSize: 12)),
                  ],
                ),
              ),
              SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  if (content.id != null) _showCommentDialog(content.id!);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.comment_outlined, size: 16, color: ThemeColor.color100),
                    SizedBox(width: 4),
                    Text('${content.commentCount}',
                        style: TextStyle(color: ThemeColor.color100, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _contentTypeIcon(String? type) {
    switch (type) {
      case 'transaction': return Icons.swap_horiz;
      case 'nft_share': return Icons.image;
      case 'music_share': return Icons.music_note;
      default: return Icons.article;
    }
  }

  // ── Discover tab ──
  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.all(Adapt.px(16)),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: ThemeColor.color0),
            decoration: InputDecoration(
              hintText: 'Search users across all Tapestry apps...',
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
                      child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))),
                    )
                  : IconButton(
                      icon: Icon(Icons.arrow_forward, color: Color(0xFF6366F1)),
                      onPressed: _performSearch,
                    ),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
        ),

        // Results
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore, size: 60, color: ThemeColor.color110),
                      SizedBox(height: 16),
                      Text('Discover users', style: TextStyle(color: ThemeColor.color100, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Search by username or wallet address',
                          style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: Adapt.px(16)),
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) => _buildProfileItem(_searchResults[i]),
                ),
        ),
      ],
    );
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _loadingSearch = true);
    try {
      _searchResults = await _tapestry.searchProfiles(query);
    } catch (_) {}
    if (mounted) setState(() => _loadingSearch = false);
  }

  Widget _buildProfileItem(TapestryProfile profile, {bool showFollowButton = true}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color((profile.username?.hashCode ?? 0).abs() % 0xFFFFFF + 0xFF000000),
                  Color(0xFF6366F1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (profile.username ?? '?')[0].toUpperCase(),
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.username ?? 'Unknown',
                    style: TextStyle(color: ThemeColor.color0, fontSize: 15, fontWeight: FontWeight.w600)),
                if (profile.bio != null)
                  Text(profile.bio!, style: TextStyle(color: ThemeColor.color100, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if (profile.walletAddress != null)
                  Text(
                    '${profile.walletAddress!.substring(0, 6)}...${profile.walletAddress!.substring(profile.walletAddress!.length - 4)}',
                    style: TextStyle(color: ThemeColor.color110, fontSize: 11, fontFamily: 'monospace'),
                  ),
                if (profile.namespace != null)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(profile.namespace!,
                        style: TextStyle(color: Color(0xFF6366F1), fontSize: 10)),
                  ),
              ],
            ),
          ),

          // Follow button
          if (showFollowButton && profile.id != null && profile.id != _tapestry.profileId)
            GestureDetector(
              onTap: () => _toggleFollow(profile),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _tapestry.isFollowingCached(profile.id!)
                      ? ThemeColor.color170
                      : Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _tapestry.isFollowingCached(profile.id!) ? 'Following' : 'Follow',
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

  Future<void> _toggleFollow(TapestryProfile profile) async {
    if (profile.id == null) return;

    final isFollowing = _tapestry.isFollowingCached(profile.id!);

    bool success;
    if (isFollowing) {
      success = await _tapestry.unfollowUser(profile.id!);
      if (success && mounted) CommonToast.instance.show(context, 'Unfollowed ${profile.username}');
    } else {
      success = await _tapestry.followUser(profile.id!);
      if (success && mounted) CommonToast.instance.show(context, 'Following ${profile.username}! ✅');
    }
    if (mounted) setState(() {});
  }

  // ── Followers tab ──
  Widget _buildFollowersTab() {
    if (_loadingFollowers) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 60, color: ThemeColor.color110),
            SizedBox(height: 16),
            Text('No followers yet', style: TextStyle(color: ThemeColor.color100, fontSize: 16)),
            SizedBox(height: 4),
            Text('Share your profile to get followers',
                style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFollowers,
      color: Color(0xFF6366F1),
      child: ListView.builder(
        padding: EdgeInsets.all(Adapt.px(16)),
        itemCount: _followers.length,
        itemBuilder: (_, i) => _buildProfileItem(_followers[i]),
      ),
    );
  }

  // ── Following tab ──
  Widget _buildFollowingTab() {
    if (_loadingFollowing) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    if (_following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined, size: 60, color: ThemeColor.color110),
            SizedBox(height: 16),
            Text('Not following anyone', style: TextStyle(color: ThemeColor.color100, fontSize: 16)),
            SizedBox(height: 4),
            Text('Use Discover to find users',
                style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFollowing,
      color: Color(0xFF6366F1),
      child: ListView.builder(
        padding: EdgeInsets.all(Adapt.px(16)),
        itemCount: _following.length,
        itemBuilder: (_, i) => _buildProfileItem(_following[i]),
      ),
    );
  }

  // ── Dialogs ──
  void _showEditProfileDialog() {
    final usernameCtl = TextEditingController(text: _tapestry.profile?.username ?? '');
    final bioCtl = TextEditingController(text: _tapestry.profile?.bio ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Edit Profile', style: TextStyle(color: ThemeColor.color0)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameCtl,
              style: TextStyle(color: ThemeColor.color0),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: ThemeColor.color100),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: bioCtl,
              style: TextStyle(color: ThemeColor.color0),
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: ThemeColor.color100),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _tapestry.updateProfile(
                username: usernameCtl.text.trim(),
                bio: bioCtl.text.trim(),
              );
              if (success && mounted) {
                CommonToast.instance.show(context, 'Profile updated! ✅');
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6366F1)),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(String contentId) {
    final commentCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Add Comment', style: TextStyle(color: ThemeColor.color0)),
        content: TextField(
          controller: commentCtl,
          style: TextStyle(color: ThemeColor.color0),
          decoration: InputDecoration(
            hintText: 'Write a comment...',
            hintStyle: TextStyle(color: ThemeColor.color110),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final text = commentCtl.text.trim();
              if (text.isEmpty) return;
              final comment = await _tapestry.addComment(contentId: contentId, text: text);
              if (comment != null && mounted) {
                CommonToast.instance.show(context, 'Comment added! 💬');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6366F1)),
            child: Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
