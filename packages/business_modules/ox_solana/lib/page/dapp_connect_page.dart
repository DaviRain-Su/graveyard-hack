import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';

import '../services/dapp_connect_service.dart';

/// DApp connection management page — view, connect, and disconnect dApps
class DappConnectPage extends StatefulWidget {
  const DappConnectPage({super.key});

  @override
  State<DappConnectPage> createState() => _DappConnectPageState();
}

class _DappConnectPageState extends State<DappConnectPage> {
  final _service = DappConnectService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _service.sessions.values.toList()
      ..sort((a, b) => b.lastActive.compareTo(a.lastActive));

    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: '🔗 DApp Connections',
        backgroundColor: ThemeColor.color190,
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              icon: Icon(Icons.link_off, color: ThemeColor.color100),
              onPressed: _disconnectAll,
            ),
        ],
      ),
      body: sessions.isEmpty ? _buildEmpty() : _buildList(sessions),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showConnectDialog,
        backgroundColor: Color(0xFF9945FF),
        icon: Icon(Icons.add_link, color: Colors.white),
        label: Text('Connect DApp', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔗', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('No Connected DApps',
              style: TextStyle(color: ThemeColor.color0, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Connect to Solana dApps to sign\ntransactions from your wallet',
              style: TextStyle(color: ThemeColor.color100, fontSize: 13),
              textAlign: TextAlign.center),
          SizedBox(height: 24),
          _buildPopularDapps(),
        ],
      ),
    );
  }

  Widget _buildPopularDapps() {
    final dapps = [
      {'name': 'Jupiter', 'url': 'https://jup.ag', 'icon': '🪐'},
      {'name': 'Raydium', 'url': 'https://raydium.io', 'icon': '☢️'},
      {'name': 'Tensor', 'url': 'https://tensor.trade', 'icon': '📊'},
      {'name': 'Magic Eden', 'url': 'https://magiceden.io', 'icon': '🪄'},
    ];

    return Column(
      children: [
        Text('Popular DApps',
            style: TextStyle(color: ThemeColor.color100, fontSize: 12)),
        SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: dapps.map((d) => _buildDappChip(d)).toList(),
        ),
      ],
    );
  }

  Widget _buildDappChip(Map<String, String> dapp) {
    return GestureDetector(
      onTap: () => _connectDapp(dapp['name']!, dapp['url']!),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ThemeColor.color180,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeColor.color160),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dapp['icon']!, style: TextStyle(fontSize: 16)),
            SizedBox(width: 6),
            Text(dapp['name']!,
                style: TextStyle(color: ThemeColor.color0, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<DappSession> sessions) {
    return ListView.builder(
      padding: EdgeInsets.all(Adapt.px(12)),
      itemCount: sessions.length,
      itemBuilder: (ctx, i) => _buildSessionCard(sessions[i]),
    );
  }

  Widget _buildSessionCard(DappSession session) {
    final timeAgo = _timeAgo(session.lastActive);

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(0xFF9945FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text('🌐', style: TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(session.dappName,
            style: TextStyle(color: ThemeColor.color0, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.domain,
                style: TextStyle(color: ThemeColor.color100, fontSize: 12)),
            SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Color(0xFF14F195),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text('Active · $timeAgo',
                    style: TextStyle(color: ThemeColor.color110, fontSize: 10)),
                if (session.isDevnet) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('devnet',
                        style: TextStyle(color: Colors.orange, fontSize: 9)),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.link_off, color: Colors.redAccent, size: 20),
          onPressed: () => _disconnect(session),
        ),
      ),
    );
  }

  void _showConnectDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Connect DApp', style: TextStyle(color: ThemeColor.color0)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: ThemeColor.color0),
              decoration: InputDecoration(
                labelText: 'DApp Name',
                labelStyle: TextStyle(color: ThemeColor.color100),
                filled: true,
                fillColor: ThemeColor.color190,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: TextStyle(color: ThemeColor.color0),
              decoration: InputDecoration(
                labelText: 'DApp URL',
                hintText: 'https://...',
                labelStyle: TextStyle(color: ThemeColor.color100),
                hintStyle: TextStyle(color: ThemeColor.color110),
                filled: true,
                fillColor: ThemeColor.color190,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
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
            onPressed: () {
              Navigator.pop(ctx);
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isNotEmpty && url.isNotEmpty) {
                _connectDapp(name, url);
              }
            },
            child: Text('Connect',
                style: TextStyle(color: Color(0xFF9945FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _connectDapp(String name, String url) {
    try {
      _service.connect(dappName: name, dappUrl: url);
      if (mounted) {
        CommonToast.instance.show(context, 'Connected to $name');
      }
    } catch (e) {
      if (mounted) {
        CommonToast.instance.show(context, '$e');
      }
    }
  }

  void _disconnect(DappSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Disconnect?', style: TextStyle(color: ThemeColor.color0)),
        content: Text('Disconnect from ${session.dappName}?',
            style: TextStyle(color: ThemeColor.color100)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _service.disconnect(session.id);
            },
            child: Text('Disconnect',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _disconnectAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text('Disconnect All?', style: TextStyle(color: ThemeColor.color0)),
        content: Text('Disconnect all ${_service.sessions.length} dApp sessions?',
            style: TextStyle(color: ThemeColor.color100)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _service.disconnectAll();
            },
            child: Text('Disconnect All',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
    return '${diff.inDays}d ago';
  }
}
