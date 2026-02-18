import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_record.dart';
import '../services/solana_wallet_service.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final _walletService = SolanaWalletService.instance;

  @override
  void initState() {
    super.initState();
    _walletService.addListener(_onChanged);
    _walletService.fetchHistory();
  }

  @override
  void dispose() {
    _walletService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: 'Transaction History',
        backgroundColor: ThemeColor.color190,
      ),
      body: _walletService.isLoadingHistory && _walletService.history.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF9945FF),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _walletService.fetchHistory(),
              child: _walletService.history.isEmpty
                  ? _buildEmptyState()
                  : _buildHistoryList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 60, color: ThemeColor.color110),
              SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(color: ThemeColor.color100, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Your transaction history will appear here',
                style: TextStyle(color: ThemeColor.color110, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return ListView.separated(
      padding: EdgeInsets.all(Adapt.px(16)),
      itemCount: _walletService.history.length,
      separatorBuilder: (_, __) => SizedBox(height: Adapt.px(4)),
      itemBuilder: (context, index) {
        return _buildTxItem(_walletService.history[index]);
      },
    );
  }

  Widget _buildTxItem(TransactionRecord tx) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Adapt.px(12)),
          onTap: () => _showTxDetail(tx),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Adapt.px(16),
              vertical: Adapt.px(14),
            ),
            child: Row(
              children: [
                // Status icon — direction-aware
                Container(
                  width: Adapt.px(40),
                  height: Adapt.px(40),
                  decoration: BoxDecoration(
                    color: tx.isError
                        ? Colors.red.withOpacity(0.15)
                        : tx.isSend
                            ? const Color(0xFF9945FF).withOpacity(0.15)
                            : const Color(0xFF14F195).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    tx.isError
                        ? Icons.error_outline
                        : tx.isSend
                            ? Icons.arrow_upward
                            : tx.isReceive
                                ? Icons.arrow_downward
                                : Icons.swap_horiz,
                    color: tx.isError
                        ? Colors.red[400]
                        : tx.isSend
                            ? const Color(0xFF9945FF)
                            : const Color(0xFF14F195),
                    size: 22,
                  ),
                ),
                SizedBox(width: Adapt.px(12)),

                // Signature & time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.isError
                            ? 'Failed'
                            : tx.isSend
                                ? 'Sent'
                                : tx.isReceive
                                    ? 'Received'
                                    : tx.shortSignature,
                        style: TextStyle(
                          color: ThemeColor.color0,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        tx.timeDisplay,
                        style: TextStyle(
                          color: ThemeColor.color100,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Amount or status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (tx.amountDisplay.isNotEmpty)
                      Text(
                        tx.amountDisplay,
                        style: TextStyle(
                          color: tx.isError
                              ? Colors.red[400]
                              : tx.isSend
                                  ? const Color(0xFF9945FF)
                                  : const Color(0xFF14F195),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tx.isError
                              ? Colors.red.withOpacity(0.15)
                              : const Color(0xFF14F195).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.statusDisplay,
                          style: TextStyle(
                            color: tx.isError ? Colors.red[400] : const Color(0xFF14F195),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (tx.fee != null) ...[
                      SizedBox(height: 2),
                      Text(
                        'Fee: ${tx.fee!.toStringAsFixed(6)}',
                        style: TextStyle(color: ThemeColor.color110, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTxDetail(TransactionRecord tx) {
    final explorerUrl = _walletService.getExplorerUrl(tx.signature);

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
            // Header
            Row(
              children: [
                Icon(
                  tx.isError ? Icons.error_outline : Icons.check_circle,
                  color: tx.isError ? Colors.red[400] : const Color(0xFF14F195),
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  tx.isError ? 'Failed Transaction' : 'Transaction',
                  style: TextStyle(
                    color: ThemeColor.color0,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: Adapt.px(20)),

            // Signature
            _buildDetailRow('Signature', tx.signature, copyable: true),
            SizedBox(height: 12),

            // Time
            _buildDetailRow('Time', tx.timeDisplay),
            SizedBox(height: 12),

            // Slot
            _buildDetailRow('Slot', tx.slot.toString()),
            SizedBox(height: 12),

            // Amount
            if (tx.solChange != null) ...[
              _buildDetailRow('Amount', tx.amountDisplay),
              SizedBox(height: 12),
            ],

            // Fee
            if (tx.fee != null) ...[
              _buildDetailRow('Fee', '${tx.fee!.toStringAsFixed(6)} SOL'),
              SizedBox(height: 12),
            ],

            // Status
            _buildDetailRow('Status', tx.statusDisplay),

            if (tx.memo != null) ...[
              SizedBox(height: 12),
              _buildDetailRow('Memo', tx.memo!),
            ],

            SizedBox(height: Adapt.px(20)),

            // Explorer buttons — Open + Copy
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(explorerUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  Clipboard.setData(ClipboardData(text: explorerUrl));
                  CommonToast.instance.show(context, 'Explorer URL copied!');
                }
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF9945FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new, size: 18, color: const Color(0xFF9945FF)),
                    SizedBox(width: 8),
                    Text(
                      'View in Solana Explorer',
                      style: TextStyle(
                        color: const Color(0xFF9945FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: explorerUrl));
                CommonToast.instance.show(context, 'Explorer URL copied!');
              },
              child: Center(
                child: Text('Copy Link',
                  style: TextStyle(color: ThemeColor.color100, fontSize: 12, decoration: TextDecoration.underline),
                ),
              ),
            ),
            SizedBox(height: Adapt.px(16)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ThemeColor.color100, fontSize: 12)),
        SizedBox(height: 4),
        GestureDetector(
          onTap: copyable
              ? () {
                  Clipboard.setData(ClipboardData(text: value));
                  CommonToast.instance.show(context, '$label copied!');
                }
              : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: ThemeColor.color0,
                    fontSize: 14,
                    fontFamily: copyable ? 'monospace' : null,
                  ),
                ),
              ),
              if (copyable)
                Icon(Icons.copy, size: 14, color: ThemeColor.color100),
            ],
          ),
        ),
      ],
    );
  }
}
