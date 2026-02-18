import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_toast.dart';

import '../models/spl_token_info.dart';
import '../services/solana_wallet_service.dart';
import '../page/send_token_page.dart';

/// Token list widget — displays SPL token holdings
class TokenListWidget extends StatelessWidget {
  const TokenListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SolanaWalletService.instance,
      builder: (context, _) {
        final service = SolanaWalletService.instance;
        final tokens = service.tokens;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.px),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tokens',
                    style: TextStyle(
                      color: ThemeColor.color0,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => service.fetchTokens(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (service.isLoadingTokens)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ThemeColor.color100,
                            ),
                          )
                        else
                          Icon(Icons.refresh, size: 16, color: ThemeColor.color100),
                        SizedBox(width: 4),
                        Text(
                          'Refresh',
                          style: TextStyle(color: ThemeColor.color100, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Adapt.px(12)),

            // Token list or empty state
            if (tokens.isEmpty && !service.isLoadingTokens)
              _buildEmptyState(context)
            else if (tokens.isEmpty && service.isLoadingTokens)
              _buildLoadingState()
            else
              ...tokens.map((token) => _buildTokenItem(context, token)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Adapt.px(24)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Column(
        children: [
          Icon(Icons.token, size: 40, color: ThemeColor.color110),
          SizedBox(height: 8),
          Text(
            'No tokens found',
            style: TextStyle(color: ThemeColor.color100, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Your SPL tokens will appear here',
            style: TextStyle(color: ThemeColor.color110, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Adapt.px(24)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: const Color(0xFF9945FF),
        ),
      ),
    );
  }

  Widget _buildTokenItem(BuildContext context, SplTokenInfo token) {
    return Container(
      margin: EdgeInsets.only(bottom: Adapt.px(2)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Adapt.px(12)),
          onTap: () => _showTokenDetail(context, token),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Adapt.px(16),
              vertical: Adapt.px(14),
            ),
            child: Row(
              children: [
                // Token icon
                _buildTokenIcon(token),
                SizedBox(width: Adapt.px(12)),

                // Token name & mint
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.symbol,
                        style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        token.name,
                        style: TextStyle(
                          color: ThemeColor.color100,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      token.balanceDisplay,
                      style: TextStyle(
                        color: ThemeColor.color0,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      token.shortMint,
                      style: TextStyle(
                        color: ThemeColor.color110,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenIcon(SplTokenInfo token) {
    // Color based on symbol hash
    final colors = [
      const Color(0xFF9945FF),
      const Color(0xFF14F195),
      const Color(0xFF3498DB),
      const Color(0xFFF39C12),
      const Color(0xFFE74C3C),
      const Color(0xFF1ABC9C),
    ];
    final color = colors[token.symbol.hashCode.abs() % colors.length];

    return Container(
      width: Adapt.px(40),
      height: Adapt.px(40),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(Adapt.px(20)),
      ),
      child: Center(
        child: Text(
          token.symbol.isNotEmpty ? token.symbol[0].toUpperCase() : '?',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showTokenDetail(BuildContext context, SplTokenInfo token) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(Adapt.px(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildTokenIcon(token),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.symbol,
                      style: TextStyle(
                        color: ThemeColor.color0,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      token.name,
                      style: TextStyle(color: ThemeColor.color100, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: Adapt.px(20)),

            // Balance
            Text('Balance', style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
            SizedBox(height: 4),
            Text(
              '${token.balanceDisplay} ${token.symbol}',
              style: TextStyle(
                color: ThemeColor.color0,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: Adapt.px(16)),

            // Mint address
            Text('Mint Address', style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
            SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: token.mintAddress));
                CommonToast.instance.show(context, 'Mint address copied!');
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeColor.color180,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        token.mintAddress,
                        style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Icon(Icons.copy, size: 16, color: ThemeColor.color100),
                  ],
                ),
              ),
            ),
            SizedBox(height: Adapt.px(16)),

            // Token account
            Text('Token Account', style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
            SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: token.tokenAccountAddress));
                CommonToast.instance.show(context, 'Token account copied!');
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeColor.color180,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        token.tokenAccountAddress,
                        style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Icon(Icons.copy, size: 16, color: ThemeColor.color100),
                  ],
                ),
              ),
            ),
            SizedBox(height: Adapt.px(20)),

            // Send button
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SendTokenPage(token: token)),
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Send ${token.symbol}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
            SizedBox(height: Adapt.px(16)),
          ],
        ),
      ),
    );
  }
}
