import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_toast.dart';
import '../services/torque_service.dart';
import '../services/solana_wallet_service.dart';

/// Torque Quests Page — Earn rewards by completing on-chain tasks
///
/// Features:
///   - Wallet-signature login (ed25519)
///   - Browse available campaigns/quests
///   - Accept and track quest progress
///   - View rewards and payouts
///   - Share referral links
class TorqueQuestsPage extends StatefulWidget {
  const TorqueQuestsPage({super.key});

  @override
  State<TorqueQuestsPage> createState() => _TorqueQuestsPageState();
}

class _TorqueQuestsPageState extends State<TorqueQuestsPage> with SingleTickerProviderStateMixin {
  final _torque = TorqueService.instance;
  final _wallet = SolanaWalletService.instance;

  late TabController _tabController;
  List<TorqueCampaign> _offers = [];
  List<TorqueJourney> _journeys = [];
  List<TorquePayout> _payouts = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (_torque.isLoggedIn) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _torque.getOffers(),
        _torque.getJourneys(),
        _torque.getPayouts(),
      ]);
      if (mounted) {
        setState(() {
          _offers = results[0] as List<TorqueCampaign>;
          _journeys = results[1] as List<TorqueJourney>;
          _payouts = results[2] as List<TorquePayout>;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _login() async {
    if (!_wallet.hasWallet) {
      CommonToast.instance.show(context, 'Create a wallet first');
      return;
    }

    setState(() { _loading = true; });
    try {
      // Use loginWithSigner which handles the full flow
      final user = await _torque.loginWithSigner(
        publicKey: _wallet.publicKey!,
        signMessage: (message) async {
          // Sign with the wallet's ed25519 key
          return _wallet.signMessage(message);
        },
      );

      if (user != null && mounted) {
        CommonToast.instance.show(context, 'Logged in to Torque! 🎯');
        _loadData();
      } else if (mounted) {
        CommonToast.instance.show(context, 'Login failed — please try again');
        setState(() { _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        CommonToast.instance.show(context, 'Login error: ${e.toString().substring(0, 60)}');
        setState(() { _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: AppBar(
        backgroundColor: ThemeColor.color190,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎯', style: TextStyle(fontSize: 20)),
            SizedBox(width: 6),
            Text('Torque Quests', style: TextStyle(color: ThemeColor.color0, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_torque.isLoggedIn)
            IconButton(
              icon: Icon(Icons.refresh, color: ThemeColor.color0),
              onPressed: _loadData,
            ),
          if (_torque.isLoggedIn)
            IconButton(
              icon: Icon(Icons.logout, color: ThemeColor.color110),
              onPressed: () async {
                await _torque.logout();
                setState(() { _offers = []; _journeys = []; _payouts = []; });
              },
            ),
        ],
        iconTheme: IconThemeData(color: ThemeColor.color0),
      ),
      body: _torque.isLoggedIn ? _buildLoggedInView() : _buildLoginView(),
    );
  }

  // ────── NOT LOGGED IN ──────

  Widget _buildLoginView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hero icon
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFF59E0B)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text('🎯', style: TextStyle(fontSize: 48)),
              ),
            ),
            SizedBox(height: 24),
            Text('Torque Quests',
              style: TextStyle(color: ThemeColor.color0, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(
              'Complete on-chain tasks and earn token rewards.\nSwap, stake, trade NFTs — get paid for it!',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeColor.color110, fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 32),

            // Feature list
            _buildFeatureRow(Icons.monetization_on, 'Earn tokens for DeFi actions'),
            SizedBox(height: 12),
            _buildFeatureRow(Icons.leaderboard, 'Compete on leaderboards'),
            SizedBox(height: 12),
            _buildFeatureRow(Icons.share, 'Share & earn referral rewards'),
            SizedBox(height: 12),
            _buildFeatureRow(Icons.lock_open, 'No API key needed — just sign'),

            SizedBox(height: 36),

            // Login button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fingerprint, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text('Sign in with Wallet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),

            if (!_wallet.hasWallet) ...[
              SizedBox(height: 12),
              Text('⚠️ Create a Solana wallet first',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Color(0xFF6366F1).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Color(0xFF6366F1), size: 18),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(color: ThemeColor.color0, fontSize: 14)),
        ),
      ],
    );
  }

  // ────── LOGGED IN ──────

  Widget _buildLoggedInView() {
    return Column(
      children: [
        // User card
        _buildUserCard(),

        // Tab bar
        TabBar(
          controller: _tabController,
          indicatorColor: Color(0xFF6366F1),
          labelColor: Color(0xFF6366F1),
          unselectedLabelColor: ThemeColor.color110,
          tabs: [
            Tab(text: 'Available (${_offers.length})'),
            Tab(text: 'Active (${_journeys.length})'),
            Tab(text: 'Rewards (${_payouts.length})'),
          ],
        ),

        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _error != null
                  ? Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('⚠️ $_error', style: TextStyle(color: ThemeColor.color110)),
                        SizedBox(height: 12),
                        TextButton(onPressed: _loadData, child: Text('Retry')),
                      ],
                    ))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOffersTab(),
                        _buildJourneysTab(),
                        _buildPayoutsTab(),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildUserCard() {
    final user = _torque.user;
    if (user == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1).withOpacity(0.15), Color(0xFFF59E0B).withOpacity(0.1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF6366F1),
            backgroundImage: user.profileImage != null ? NetworkImage(user.profileImage!) : null,
            child: user.profileImage == null
                ? Text(user.displayName[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                  style: TextStyle(color: ThemeColor.color0, fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Row(
                  children: [
                    if (user.isPublisher) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Publisher', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(width: 6),
                    ],
                    Text('${user.pubKey.substring(0, 8)}...', style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          // Stats
          Column(
            children: [
              Text('${_journeys.where((j) => j.isActive).length}', style: TextStyle(color: Color(0xFF6366F1), fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Active', style: TextStyle(color: ThemeColor.color110, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ────── OFFERS TAB ──────

  Widget _buildOffersTab() {
    if (_offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎯', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No available quests', style: TextStyle(color: ThemeColor.color110, fontSize: 16)),
            SizedBox(height: 8),
            Text('Check back later for new campaigns!', style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _offers.length,
        itemBuilder: (ctx, i) => _buildCampaignCard(_offers[i]),
      ),
    );
  }

  Widget _buildCampaignCard(TorqueCampaign campaign) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColor.color160),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image (if available)
          if (campaign.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: Image.network(campaign.imageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SizedBox.shrink()),
            ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Type badge
                Row(
                  children: [
                    Expanded(
                      child: Text(campaign.title ?? 'Quest',
                        style: TextStyle(color: ThemeColor.color0, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    if (campaign.type != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(campaign.type!, style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                  ],
                ),

                if (campaign.description != null) ...[
                  SizedBox(height: 8),
                  Text(campaign.description!,
                    style: TextStyle(color: ThemeColor.color110, fontSize: 13, height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                ],

                SizedBox(height: 12),

                // Reward + Spots
                Row(
                  children: [
                    // Reward
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('💰', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 4),
                          Text(campaign.rewardDisplay,
                            style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),

                    // Requirements count
                    if (campaign.requirements.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: ThemeColor.color170,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${campaign.requirements.length} steps',
                          style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
                      ),

                    Spacer(),

                    // Remaining spots
                    Text('${campaign.remainingConversions} left',
                      style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
                  ],
                ),

                SizedBox(height: 12),

                // Accept button
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => _acceptCampaign(campaign),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Accept Quest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptCampaign(TorqueCampaign campaign) async {
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Accept Quest?', style: TextStyle(color: ThemeColor.color0)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(campaign.title ?? 'Quest', style: TextStyle(color: ThemeColor.color0, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Reward: ${campaign.rewardDisplay}', style: TextStyle(color: Color(0xFFF59E0B))),
            SizedBox(height: 4),
            Text('Steps: ${campaign.requirements.length}', style: TextStyle(color: ThemeColor.color110)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6366F1)),
            child: Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final journey = await _torque.acceptCampaign(campaign.id);
    if (journey != null && mounted) {
      CommonToast.instance.show(context, 'Quest accepted! 🎯');
      _loadData();
    } else if (mounted) {
      CommonToast.instance.show(context, 'Failed to accept quest');
    }
  }

  // ────── JOURNEYS TAB ──────

  Widget _buildJourneysTab() {
    if (_journeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📋', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No active quests', style: TextStyle(color: ThemeColor.color110, fontSize: 16)),
            SizedBox(height: 8),
            Text('Accept a quest from the Available tab', style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _journeys.length,
      itemBuilder: (ctx, i) => _buildJourneyCard(_journeys[i]),
    );
  }

  Widget _buildJourneyCard(TorqueJourney journey) {
    final progress = (journey.totalSteps != null && journey.totalSteps! > 0 && journey.currentStep != null)
        ? journey.currentStep! / journey.totalSteps!
        : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: journey.isCompleted ? Color(0xFF22C55E).withOpacity(0.3) : ThemeColor.color160),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(journey.isCompleted ? '✅' : '🔄', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Campaign ${journey.campaignId?.substring(0, 12) ?? "?"}...',
                  style: TextStyle(color: ThemeColor.color0, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (journey.isCompleted ? Color(0xFF22C55E) : Color(0xFF6366F1)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(journey.status ?? 'ACTIVE',
                  style: TextStyle(
                    color: journey.isCompleted ? Color(0xFF22C55E) : Color(0xFF6366F1),
                    fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          if (journey.totalSteps != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: ThemeColor.color170,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                      minHeight: 6,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Text('${journey.currentStep ?? 0}/${journey.totalSteps}',
                  style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ────── PAYOUTS TAB ──────

  Widget _buildPayoutsTab() {
    if (_payouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('💰', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No rewards yet', style: TextStyle(color: ThemeColor.color110, fontSize: 16)),
            SizedBox(height: 8),
            Text('Complete quests to earn rewards!', style: TextStyle(color: ThemeColor.color110, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _payouts.length,
      itemBuilder: (ctx, i) {
        final p = _payouts[i];
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeColor.color180,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text('💰', style: TextStyle(fontSize: 20))),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.amount ?? "?"} ${p.token ?? "tokens"}',
                      style: TextStyle(color: ThemeColor.color0, fontSize: 15, fontWeight: FontWeight.w600)),
                    if (p.payoutTx != null)
                      Text('tx: ${p.payoutTx!.substring(0, 16)}...',
                        style: TextStyle(color: ThemeColor.color110, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
            ],
          ),
        );
      },
    );
  }
}
