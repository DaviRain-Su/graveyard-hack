import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';

import '../models/spl_token_info.dart';
import '../services/solana_wallet_service.dart';

class SendTokenPage extends StatefulWidget {
  final SplTokenInfo token;
  const SendTokenPage({super.key, required this.token});

  @override
  State<SendTokenPage> createState() => _SendTokenPageState();
}

class _SendTokenPageState extends State<SendTokenPage> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _walletService = SolanaWalletService.instance;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: 'Send ${widget.token.symbol}',
        backgroundColor: ThemeColor.color190,
      ),
      body: Padding(
        padding: EdgeInsets.all(Adapt.px(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Token info header
            Container(
              padding: EdgeInsets.all(Adapt.px(16)),
              decoration: BoxDecoration(
                color: ThemeColor.color180,
                borderRadius: BorderRadius.circular(Adapt.px(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9945FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: Text(
                        widget.token.symbol.isNotEmpty ? widget.token.symbol[0] : '?',
                        style: TextStyle(color: const Color(0xFF9945FF), fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.token.symbol, style: TextStyle(color: ThemeColor.color0, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Balance: ${widget.token.balanceDisplay}', style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: Adapt.px(20)),

            // Recipient address
            Text('Recipient Address', style: TextStyle(color: ThemeColor.color100, fontSize: 14)),
            SizedBox(height: 8),
            TextField(
              controller: _addressController,
              style: TextStyle(color: ThemeColor.color0, fontSize: 14, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Solana address...',
                hintStyle: TextStyle(color: ThemeColor.color110),
                filled: true,
                fillColor: ThemeColor.color180,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: Adapt.px(16)),

            // Amount
            Text('Amount', style: TextStyle(color: ThemeColor.color100, fontSize: 14)),
            SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: ThemeColor.color0, fontSize: 24),
              decoration: InputDecoration(
                hintText: '0.0',
                hintStyle: TextStyle(color: ThemeColor.color110),
                filled: true,
                fillColor: ThemeColor.color180,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: TextButton(
                  onPressed: () {
                    _amountController.text = widget.token.balance.toString();
                  },
                  child: Text('MAX', style: TextStyle(color: const Color(0xFF9945FF), fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const Spacer(),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9945FF),
                  padding: EdgeInsets.symmetric(vertical: Adapt.px(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Send ${widget.token.symbol}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: Adapt.px(24)),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final address = _addressController.text.trim();
    final amountStr = _amountController.text.trim();

    if (address.isEmpty) {
      CommonToast.instance.show(context, 'Enter recipient address');
      return;
    }
    if (address.length < 32 || address.length > 44) {
      CommonToast.instance.show(context, 'Invalid Solana address');
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      CommonToast.instance.show(context, 'Enter valid amount');
      return;
    }
    if (amount > widget.token.balance) {
      CommonToast.instance.show(context, 'Insufficient ${widget.token.symbol} balance');
      return;
    }

    try {
      OXLoading.show();
      final sig = await _walletService.sendSplToken(
        mintAddress: widget.token.mintAddress,
        toAddress: address,
        amount: amount,
        decimals: widget.token.decimals,
      );
      OXLoading.dismiss();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThemeColor.color180,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF14F195), size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('Sent!', style: TextStyle(color: ThemeColor.color0))),
              ],
            ),
            content: Text(
              '$amountStr ${widget.token.symbol} sent successfully',
              style: TextStyle(color: ThemeColor.color0),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text('Done', style: TextStyle(color: Color(0xFF9945FF))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) {
        CommonToast.instance.show(context, 'Failed: $e');
      }
    }
  }
}
