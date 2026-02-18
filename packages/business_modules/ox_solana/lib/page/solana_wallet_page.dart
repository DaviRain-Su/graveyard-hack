import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';

import '../services/solana_wallet_service.dart';
import '../widgets/token_list_widget.dart';
import 'send_sol_page.dart';
import 'receive_page.dart';

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
              SizedBox(width: Adapt.px(12)),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.arrow_downward,
                  label: 'Receive',
                  color: const Color(0xFF14F195), // Solana green
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ReceivePage())),
                ),
              ),
              SizedBox(width: Adapt.px(12)),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Refresh',
                  color: ThemeColor.color100,
                  onTap: () async {
                    await _walletService.refreshBalance();
                    if (mounted) {
                      CommonToast.instance.show(context, 'Balance refreshed');
                    }
                  },
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

          // Nostr binding info
          if (_walletService.nostrPubkey != null) ...[
            _buildNostrBindingInfo(),
            SizedBox(height: Adapt.px(16)),
          ],

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
              : Text(
                  '${_walletService.balance.toStringAsFixed(4)} SOL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
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
    return Container(
      padding: EdgeInsets.all(Adapt.px(16)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Identity Binding',
              style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.link, size: 16, color: const Color(0xFF9945FF)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nostr ↔ Solana linked via Tapestry',
                  style: TextStyle(color: ThemeColor.color0, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF14F195), size: 28),
            SizedBox(width: 8),
            Text('Wallet Created!', style: TextStyle(color: ThemeColor.color0)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Solana address:',
              style: TextStyle(color: ThemeColor.color100, fontSize: 13),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeColor.color190,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _walletService.address,
                style: TextStyle(
                  color: ThemeColor.color0,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              '🟠 You are on Devnet. Tap "Request Airdrop" to get free test SOL.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _walletService.address));
              CommonToast.instance.show(context, 'Address copied!');
            },
            child: Text('Copy Address', style: TextStyle(color: ThemeColor.color100)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: Color(0xFF9945FF))),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Import Mnemonic',
            style: TextStyle(color: ThemeColor.color0)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: ThemeColor.color0),
          decoration: InputDecoration(
            hintText: 'Enter 12 or 24 word mnemonic...',
            hintStyle: TextStyle(color: ThemeColor.color100),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                OXLoading.show();
                await _walletService
                    .importFromMnemonic(controller.text.trim());
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
