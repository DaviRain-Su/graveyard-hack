import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';

import '../services/solana_wallet_service.dart';
import '../services/tapestry_service.dart';
import '../services/price_service.dart';
import '../widgets/token_list_widget.dart';
import 'send_sol_page.dart';
import 'receive_page.dart';
import 'transaction_history_page.dart';
import 'swap_page.dart';
import 'audius_page.dart';

/// Main Solana wallet page — shows balance, address, and action buttons
class SolanaWalletPage extends StatefulWidget {
  const SolanaWalletPage({super.key});

  @override
  State<SolanaWalletPage> createState() => _SolanaWalletPageState();
}

class _SolanaWalletPageState extends State<SolanaWalletPage> {
  final _walletService = SolanaWalletService.instance;

  @override
  void initState() {
    super.initState();
    _walletService.addListener(_onWalletChanged);
    if (_walletService.hasWallet) {
      _walletService.refreshBalance();
      _walletService.fetchTokens();
      // Fetch prices in background (non-blocking)
      PriceService.instance.fetchPrices();
    }
  }

  @override
  void dispose() {
    _walletService.removeListener(_onWalletChanged);
    super.dispose();
  }

  void _onWalletChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: 'Solana Wallet',
        backgroundColor: ThemeColor.color190,
        actions: [
          IconButton(
            icon: Icon(
              _walletService.isDevnet ? Icons.bug_report : Icons.public,
              color: _walletService.isDevnet ? Colors.orange : ThemeColor.color0,
            ),
            onPressed: _toggleNetwork,
            tooltip: _walletService.isDevnet ? 'Devnet' : 'Mainnet',
          ),
        ],
      ),
      body: _walletService.hasWallet ? _buildWalletView() : _buildCreateView(),
    );
  }

  Widget _buildCreateView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Adapt.px(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 80, color: ThemeColor.color100),
            SizedBox(height: Adapt.px(24)),
            Text(
              'No Solana Wallet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ThemeColor.color0,
              ),
            ),
            SizedBox(height: Adapt.px(8)),
            Text(
              'Create a new wallet or import an existing one',
              style: TextStyle(fontSize: 14, color: ThemeColor.color100),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Adapt.px(40)),
            _buildButton(
              label: 'Create New Wallet',
              icon: Icons.add,
              color: const Color(0xFF9945FF), // Solana purple
              onTap: _createWallet,
            ),
            SizedBox(height: Adapt.px(16)),
            _buildButton(
              label: 'Import from Mnemonic',
              icon: Icons.download,
              color: ThemeColor.color100,
              onTap: _showImportDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletView() {
    return RefreshIndicator(
      onRefresh: _walletService.refreshBalance,
      child: ListView(
        padding: EdgeInsets.all(Adapt.px(16)),
        children: [
          // Network indicator
          if (_walletService.isDevnet)
            Container(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bug_report, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('Devnet Mode',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ],
              ),
            ),
          SizedBox(height: Adapt.px(16)),

          // Balance card
          _buildBalanceCard(),
          SizedBox(height: Adapt.px(24)),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.arrow_upward,
                  label: 'Send',
                  color: const Color(0xFF9945FF),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SendSolPage())),
                ),
              ),
              SizedBox(width: Adapt.px(10)),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.arrow_downward,
                  label: 'Receive',
                  color: const Color(0xFF14F195),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ReceivePage())),
                ),
              ),
              SizedBox(width: Adapt.px(10)),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.swap_horiz,
                  label: 'Swap',
                  color: const Color(0xFFF39C12),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SwapPage())),
                ),
              ),
              SizedBox(width: Adapt.px(10)),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history,
                  label: 'History',
                  color: const Color(0xFF3498DB),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TransactionHistoryPage())),
                ),
              ),
            ],
          ),

          // Devnet Airdrop button
          if (_walletService.isDevnet) ...[
            SizedBox(height: Adapt.px(16)),
            _buildAirdropButton(),
          ],
          SizedBox(height: Adapt.px(24)),

          // SPL Token list
          const TokenListWidget(),
          SizedBox(height: Adapt.px(24)),

          // Address section
          _buildAddressSection(),
          SizedBox(height: Adapt.px(16)),

          // Explorer link
          _buildExplorerLink(),
          SizedBox(height: Adapt.px(16)),

          // Audius music shortcut
          _buildAudiusShortcut(),
          SizedBox(height: Adapt.px(16)),

          // Nostr binding info
          if (_walletService.nostrPubkey != null) ...[
            _buildNostrBindingInfo(),
            SizedBox(height: Adapt.px(16)),
          ],

          // Backup recovery phrase
          if (_walletService.hasMnemonic) ...[
            _buildBackupButton(),
            SizedBox(height: Adapt.px(12)),
          ],

          // RPC Settings
          _buildRpcSetting(),
          SizedBox(height: Adapt.px(12)),

          // Delete wallet
          _buildDeleteWalletButton(),
          SizedBox(height: Adapt.px(40)),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: EdgeInsets.all(Adapt.px(24)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9945FF), Color(0xFF14F195)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Adapt.px(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9945FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SOL Balance',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(height: Adapt.px(8)),
          _walletService.isLoading
              ? const SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_walletService.balance.toStringAsFixed(4)} SOL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (PriceService.instance.solPrice > 0 && !_walletService.isDevnet) ...[
                      SizedBox(height: 4),
                      Text(
                        '≈ ${PriceService.instance.formatUsdValue(_walletService.balance, 'So11111111111111111111111111111111111111112')}',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ],
                ),
          if (_walletService.error != null) ...[
            SizedBox(height: 8),
            Text(_walletService.error!,
                style: TextStyle(color: Colors.red[200], fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    final addr = _walletService.address;
    final shortAddr =
        '${addr.substring(0, 8)}...${addr.substring(addr.length - 8)}';

    return Container(
      padding: EdgeInsets.all(Adapt.px(16)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wallet Address',
              style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: addr));
              CommonToast.instance.show(context, 'Address copied!');
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(shortAddr,
                      style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 16,
                          fontFamily: 'monospace')),
                ),
                Icon(Icons.copy, size: 18, color: ThemeColor.color100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNostrBindingInfo() {
    final tapestry = TapestryService.instance;
    final isBound = tapestry.hasBoundProfile;

    return Container(
      padding: EdgeInsets.all(Adapt.px(16)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Identity Binding',
                  style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isBound
                      ? const Color(0xFF14F195).withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBound ? 'Linked' : 'Not Linked',
                  style: TextStyle(
                    color: isBound ? const Color(0xFF14F195) : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (isBound) ...[
            Row(
              children: [
                Icon(Icons.link, size: 16, color: const Color(0xFF9945FF)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tapestry.hasApiKey
                        ? 'Nostr ↔ Solana linked via Tapestry'
                        : 'Nostr ↔ Solana linked (local)',
                    style: TextStyle(color: ThemeColor.color0, fontSize: 14),
                  ),
                ),
              ],
            ),
            if (tapestry.profile?.username != null) ...[
              SizedBox(height: 4),
              Text(
                'Profile: ${tapestry.profile!.username}',
                style: TextStyle(color: ThemeColor.color100, fontSize: 12),
              ),
            ],
            if (!tapestry.hasApiKey) ...[
              SizedBox(height: 4),
              Text(
                'Add Tapestry API key in settings to sync on-chain',
                style: TextStyle(color: ThemeColor.color110, fontSize: 11),
              ),
            ],
          ] else ...[
            Text(
              'Link your Nostr identity with your Solana wallet so contacts can send you tokens directly.',
              style: TextStyle(color: ThemeColor.color100, fontSize: 13),
            ),
            SizedBox(height: 12),
            GestureDetector(
              onTap: _bindTapestry,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF9945FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Link Nostr ↔ Solana',
                    style: TextStyle(
                      color: const Color(0xFF9945FF),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _bindTapestry() async {
    final nostrPubkey = _walletService.nostrPubkey;
    if (nostrPubkey == null || nostrPubkey.isEmpty) {
      CommonToast.instance.show(context, 'Please login to Nostr first');
      return;
    }

    try {
      OXLoading.show();
      final profile = await TapestryService.instance.createProfile(
        nostrPubkey: nostrPubkey,
        solanaAddress: _walletService.address,
      );
      OXLoading.dismiss();

      if (mounted) {
        if (profile != null) {
          final msg = profile.isLocal
              ? 'Identity linked locally! ✅'
              : 'Identity linked on-chain! ✅';
          CommonToast.instance.show(context, msg);
          setState(() {});
        } else {
          CommonToast.instance.show(context, 'Binding failed');
        }
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) {
        CommonToast.instance.show(context, 'Error: $e');
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Adapt.px(16)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(Adapt.px(12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: Adapt.px(14)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Adapt.px(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildAirdropButton() {
    return GestureDetector(
      onTap: _requestAirdrop,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: Adapt.px(14)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.withOpacity(0.2),
              Colors.amber.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(Adapt.px(12)),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Request Devnet Airdrop (1 SOL)',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAirdrop() async {
    try {
      OXLoading.show();
      final sig = await _walletService.requestAirdrop();
      OXLoading.dismiss();
      if (mounted) {
        CommonToast.instance.show(context, 'Airdrop received! ✅');
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) {
        CommonToast.instance.show(context, 'Airdrop failed: $e');
      }
    }
  }

  Future<void> _createWallet() async {
    try {
      OXLoading.show();
      // Auto-switch to devnet for new wallets (development friendly)
      if (!_walletService.isDevnet) {
        await _walletService.switchNetwork(devnet: true);
      }
      await _walletService.createWallet();
      OXLoading.dismiss();
      if (mounted) {
        _showWalletCreatedDialog();
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) {
        CommonToast.instance.show(context, 'Failed: $e');
      }
    }
  }

  void _showWalletCreatedDialog() {
    final mnemonic = _walletService.exportMnemonic();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF14F195), size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Wallet Created!', style: TextStyle(color: ThemeColor.color0)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recovery phrase
              if (mnemonic != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red[400], size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Back up your recovery phrase NOW! You cannot view it again after closing.',
                          style: TextStyle(color: Colors.red[400], fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text('Recovery Phrase:', style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeColor.color190,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: mnemonic.split(' ').asMap().entries.map((e) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeColor.color180,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${e.key + 1}. ${e.value}',
                          style: TextStyle(color: ThemeColor.color0, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 12),
              ],

              // Address
              Text('Your Solana address:', style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeColor.color190,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _walletService.address,
                  style: TextStyle(color: ThemeColor.color0, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '🟠 You are on Devnet. Tap "Request Airdrop" to get free test SOL.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          if (mnemonic != null)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mnemonic));
                CommonToast.instance.show(context, 'Recovery phrase copied! Store it safely.');
              },
              child: Text('Copy Phrase', style: TextStyle(color: Colors.red[400])),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('I\'ve Backed Up', style: TextStyle(color: Color(0xFF9945FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final text = controller.text.trim();
          final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;

          return AlertDialog(
            backgroundColor: ThemeColor.color180,
            title: Text('Import Mnemonic',
                style: TextStyle(color: ThemeColor.color0)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: TextStyle(color: ThemeColor.color0),
                  onChanged: (_) => setDialogState(() {
                    validationError = null;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Enter 12 or 24 word mnemonic...',
                    hintStyle: TextStyle(color: ThemeColor.color100),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorText: validationError,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '$wordCount words entered${wordCount > 0 ? (wordCount == 12 || wordCount == 24 ? ' ✓' : ' (need 12 or 24)') : ''}',
                  style: TextStyle(
                    color: (wordCount == 12 || wordCount == 24) ? const Color(0xFF14F195) : ThemeColor.color100,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
              ),
              TextButton(
                onPressed: () async {
                  // Validate first
                  if (!SolanaWalletService.isValidMnemonic(text)) {
                    setDialogState(() {
                      validationError = wordCount != 12 && wordCount != 24
                          ? 'Must be 12 or 24 words (got $wordCount)'
                          : 'Invalid BIP39 mnemonic words';
                    });
                    return;
                  }

                  Navigator.pop(ctx);
                  try {
                    OXLoading.show();
                    await _walletService.importFromMnemonic(text);
                    OXLoading.dismiss();
                    if (mounted) {
                      CommonToast.instance.show(context, 'Wallet imported!');
                    }
                  } catch (e) {
                    OXLoading.dismiss();
                    if (mounted) {
                      CommonToast.instance.show(context, 'Import failed: $e');
                    }
                  }
                },
                child: const Text('Import',
                    style: TextStyle(color: Color(0xFF9945FF))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExplorerLink() {
    return GestureDetector(
      onTap: () {
        final url = _walletService.addressExplorerUrl;
        Clipboard.setData(ClipboardData(text: url));
        CommonToast.instance.show(context, 'Explorer URL copied!');
      },
      child: Container(
        padding: EdgeInsets.all(Adapt.px(16)),
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(Adapt.px(12)),
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 18, color: const Color(0xFF9945FF)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'View on Solana Explorer',
                style: TextStyle(color: const Color(0xFF9945FF), fontSize: 14),
              ),
            ),
            Icon(Icons.copy, size: 16, color: ThemeColor.color100),
          ],
        ),
      ),
    );
  }

  Widget _buildAudiusShortcut() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AudiusPage()),
      ),
      child: Container(
        padding: EdgeInsets.all(Adapt.px(16)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7E1BCC).withOpacity(0.15), Color(0xFFCC0FE0).withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(Adapt.px(12)),
          border: Border.all(color: Color(0xFF7E1BCC).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFF7E1BCC).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text('🎵', style: TextStyle(fontSize: 18))),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Audius Music',
                      style: TextStyle(color: ThemeColor.color0, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Discover & share decentralized music',
                      style: TextStyle(color: ThemeColor.color100, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: ThemeColor.color100),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupButton() {
    return GestureDetector(
      onTap: _showBackupMnemonic,
      child: Container(
        padding: EdgeInsets.all(Adapt.px(16)),
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(Adapt.px(12)),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_outlined, size: 18, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Backup Recovery Phrase',
                style: TextStyle(color: Colors.orange, fontSize: 14),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: ThemeColor.color100),
          ],
        ),
      ),
    );
  }

  void _showBackupMnemonic() {
    final mnemonic = _walletService.exportMnemonic();
    if (mnemonic == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(Adapt.px(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: Colors.orange, size: 24),
                SizedBox(width: 10),
                Text('Recovery Phrase',
                    style: TextStyle(color: ThemeColor.color0, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Never share your recovery phrase. Anyone with these words can access your funds.',
                style: TextStyle(color: Colors.red[400], fontSize: 12),
              ),
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeColor.color180,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mnemonic.split(' ').asMap().entries.map((e) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ThemeColor.color190,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: TextStyle(color: ThemeColor.color0, fontSize: 14, fontFamily: 'monospace'),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: mnemonic));
                CommonToast.instance.show(context, 'Copied! Store it safely.');
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('Copy Recovery Phrase',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            SizedBox(height: Adapt.px(16)),
          ],
        ),
      ),
    );
  }

  Widget _buildRpcSetting() {
    return GestureDetector(
      onTap: _showRpcSettingDialog,
      child: Container(
        padding: EdgeInsets.all(Adapt.px(16)),
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(Adapt.px(12)),
        ),
        child: Row(
          children: [
            Icon(Icons.dns_outlined, size: 18, color: ThemeColor.color100),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RPC Endpoint', style: TextStyle(color: ThemeColor.color0, fontSize: 14)),
                  SizedBox(height: 2),
                  Text(
                    _walletService.hasCustomRpc ? 'Custom RPC' : 'Default (public, rate-limited)',
                    style: TextStyle(color: ThemeColor.color100, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: ThemeColor.color100),
          ],
        ),
      ),
    );
  }

  void _showRpcSettingDialog() {
    final controller = TextEditingController(
      text: _walletService.hasCustomRpc ? _walletService.effectiveRpcUrl : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Mainnet RPC Endpoint', style: TextStyle(color: ThemeColor.color0)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Public RPC has strict rate limits. Use a custom RPC for better performance (e.g. Helius, QuickNode, Alchemy).',
              style: TextStyle(color: ThemeColor.color100, fontSize: 12),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              style: TextStyle(color: ThemeColor.color0, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'https://your-rpc-endpoint.com',
                hintStyle: TextStyle(color: ThemeColor.color110, fontSize: 12),
                filled: true,
                fillColor: ThemeColor.color190,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          if (_walletService.hasCustomRpc)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _walletService.setCustomRpc(null);
                if (mounted) {
                  CommonToast.instance.show(context, 'Reset to default RPC');
                }
              },
              child: Text('Reset', style: TextStyle(color: Colors.orange)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty || !url.startsWith('http')) {
                CommonToast.instance.show(context, 'Enter a valid URL');
                return;
              }
              Navigator.pop(ctx);
              await _walletService.setCustomRpc(url);
              if (mounted) {
                CommonToast.instance.show(context, 'RPC endpoint updated');
              }
            },
            child: Text('Save', style: TextStyle(color: const Color(0xFF9945FF))),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteWalletButton() {
    return GestureDetector(
      onTap: _confirmDeleteWallet,
      child: Container(
        padding: EdgeInsets.all(Adapt.px(16)),
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(Adapt.px(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
            SizedBox(width: 8),
            Text(
              'Delete Wallet',
              style: TextStyle(color: Colors.red[400], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteWallet() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Delete Wallet?', style: TextStyle(color: ThemeColor.color0)),
        content: Text(
          'This will remove your Solana wallet from this device. Make sure you have backed up your keys!',
          style: TextStyle(color: ThemeColor.color100),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _walletService.deleteWallet();
              if (mounted) {
                CommonToast.instance.show(context, 'Wallet deleted');
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNetwork() async {
    final newDevnet = !_walletService.isDevnet;
    await _walletService.switchNetwork(devnet: newDevnet);
    if (mounted) {
      CommonToast.instance
          .show(context, 'Switched to ${newDevnet ? "Devnet" : "Mainnet"}');
    }
  }
}
