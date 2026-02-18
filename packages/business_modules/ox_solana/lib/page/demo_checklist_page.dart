import 'package:flutter/material.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_module_service/ox_module_service.dart';

class DemoChecklistPage extends StatelessWidget {
  const DemoChecklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: '🎬 Demo Checklist',
        backgroundColor: ThemeColor.color190,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.px),
        children: [
          _buildSection(
            title: '✅ Core Flow (90s)',
            items: [
              _DemoItem('Open Solana Wallet', 'Show balance + network switch', () {
                OXModuleService.pushPage(context, 'ox_solana', 'SolanaWalletPage', {});
              }),
              _DemoItem('Devnet/Testnet Airdrop', 'Tap Request Airdrop', () {
                OXModuleService.pushPage(context, 'ox_solana', 'SolanaWalletPage', {});
              }),
              _DemoItem('Demo Transfer', 'Run Demo Transfer button', () {
                OXModuleService.pushPage(context, 'ox_solana', 'SolanaWalletPage', {});
              }),
              _DemoItem('Send SOL in Chat', 'Open chat + SOL Transfer', () {
                OXModuleService.pushPage(context, 'ox_chat', 'ChatChooseSharePage', {
                  'url': 'Open any chat and tap + → SOL Transfer',
                });
              }),
            ],
          ),
          _buildSection(
            title: '🎵 Audius Track',
            items: [
              _DemoItem('Search & Play', 'Open Audius + play a song', () {
                OXModuleService.pushPage(context, 'ox_solana', 'AudiusPage', {});
              }),
              _DemoItem('Share in Chat', 'Pick a track → send card', () {
                OXModuleService.pushPage(context, 'ox_solana', 'AudiusPage', {});
              }),
            ],
          ),
          _buildSection(
            title: '🎫 KYD Events',
            items: [
              _DemoItem('Browse Events', 'Open KYD event list', () {
                OXModuleService.pushPage(context, 'ox_solana', 'KydEventsPage', {});
              }),
              _DemoItem('Share Event', 'Send event card in chat', () {
                OXModuleService.pushPage(context, 'ox_solana', 'KydEventsPage', {});
              }),
            ],
          ),
          _buildSection(
            title: '🖼️ NFT + DRiP',
            items: [
              _DemoItem('NFT Gallery', 'Show wallet NFTs', () {
                OXModuleService.pushPage(context, 'ox_solana', 'NftGalleryPage', {});
              }),
              _DemoItem('DRiP Tab', 'Open DRiP Collection/Discover', () {
                OXModuleService.pushPage(context, 'ox_solana', 'NftGalleryPage', {});
              }),
            ],
          ),
          _buildSection(
            title: '⚡ Torque Quests',
            items: [
              _DemoItem('Quest Board', 'Open Torque quests', () {
                OXModuleService.pushPage(context, 'ox_solana', 'TorqueQuestsPage', {});
              }),
            ],
          ),
          SizedBox(height: 10.px),
          _buildScriptCard(context),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<_DemoItem> items}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.px),
      padding: EdgeInsets.all(14.px),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColor.color160),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: ThemeColor.color0, fontSize: 15, fontWeight: FontWeight.bold)),
          SizedBox(height: 10.px),
          ...items.map((e) => _buildItem(e)).toList(),
        ],
      ),
    );
  }

  Widget _buildItem(_DemoItem item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.title, style: TextStyle(color: ThemeColor.color0, fontSize: 14)),
      subtitle: Text(item.subtitle, style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
      trailing: Text('Open', style: TextStyle(color: Color(0xFF9945FF))),
      onTap: item.onTap,
    );
  }

  Widget _buildScriptCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.px),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9945FF).withOpacity(0.2), Color(0xFF14F195).withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎤 Demo Script (2-3 min)',
              style: TextStyle(color: ThemeColor.color0, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text(
            '1. Open Solana Wallet → switch Devnet/Testnet → Airdrop\n'
            '2. Run Demo Transfer → show signature + explorer\n'
            '3. Open Audius → play → share to chat\n'
            '4. Share NFT + DRiP tab\n'
            '5. KYD Events → share event card\n'
            '6. Torque quests + Tapestry social\n'
            'Finish: “Solana is native in chat.”',
            style: TextStyle(color: ThemeColor.color100, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DemoItem {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _DemoItem(this.title, this.subtitle, this.onTap);
}
