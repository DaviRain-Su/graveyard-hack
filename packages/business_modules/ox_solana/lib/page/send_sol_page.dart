import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';

import '../services/solana_wallet_service.dart';

class SendSolPage extends StatefulWidget {
  final String recipientAddress;
  const SendSolPage({super.key, this.recipientAddress = ''});

  @override
  State<SendSolPage> createState() => _SendSolPageState();
}

class _SendSolPageState extends State<SendSolPage> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _walletService = SolanaWalletService.instance;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipientAddress.isNotEmpty) {
      _addressController.text = widget.recipientAddress;
    }
  }

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
        title: 'Send SOL',
        backgroundColor: ThemeColor.color190,
      ),
      body: Padding(
        padding: EdgeInsets.all(Adapt.px(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Available balance
            Container(
              padding: EdgeInsets.all(Adapt.px(12)),
              decoration: BoxDecoration(
                color: ThemeColor.color180,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text('Available: ',
                      style: TextStyle(color: ThemeColor.color100)),
                  Text(
                    '${_walletService.balance.toStringAsFixed(4)} SOL',
                    style: TextStyle(
                        color: ThemeColor.color0, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: Adapt.px(20)),

            // Recipient address
            Text('Recipient Address',
                style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
            SizedBox(height: 8),
            TextField(
              controller: _addressController,
              style: TextStyle(color: ThemeColor.color0, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Enter Solana address...',
                hintStyle: TextStyle(color: ThemeColor.color110),
                filled: true,
                fillColor: ThemeColor.color180,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: Adapt.px(20)),

            // Amount
            Text('Amount (SOL)',
                style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
            SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                suffixText: 'SOL',
                suffixStyle: TextStyle(color: ThemeColor.color100),
              ),
            ),
            SizedBox(height: 8),
            // Max button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // Leave some for fees
                  final max = (_walletService.balance - 0.001).clamp(0, double.infinity);
                  _amountController.text = max.toStringAsFixed(4);
                },
                child: const Text('MAX',
                    style: TextStyle(color: Color(0xFF9945FF))),
              ),
            ),
            const Spacer(),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendSol,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9945FF),
                  padding: EdgeInsets.symmetric(vertical: Adapt.px(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Send SOL',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            SizedBox(height: Adapt.px(16)),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSol() async {
    final address = _addressController.text.trim();
    final amountStr = _amountController.text.trim();

    if (address.isEmpty) {
      CommonToast.instance.show(context, 'Please enter recipient address');
      return;
    }
    if (address.length < 32 || address.length > 44) {
      CommonToast.instance.show(context, 'Invalid Solana address');
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      CommonToast.instance.show(context, 'Please enter valid amount');
      return;
    }
    if (amount > _walletService.balance) {
      CommonToast.instance.show(context, 'Insufficient balance');
      return;
    }

    setState(() => _isSending = true);

    try {
      OXLoading.show();
      final signature = await _walletService.sendSol(
        toAddress: address,
        amount: amount,
      );
      OXLoading.dismiss();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThemeColor.color180,
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF14F195)),
                const SizedBox(width: 8),
                Text('Sent!', style: TextStyle(color: ThemeColor.color0)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$amount SOL sent to',
                    style: TextStyle(color: ThemeColor.color0)),
                SizedBox(height: 4),
                Text(
                  '${address.substring(0, 8)}...${address.substring(address.length - 8)}',
                  style: TextStyle(
                      color: ThemeColor.color100, fontFamily: 'monospace'),
                ),
                SizedBox(height: 12),
                Text('Signature:',
                    style:
                        TextStyle(color: ThemeColor.color100, fontSize: 12)),
                Text(
                  '${signature.substring(0, 16)}...',
                  style: TextStyle(
                      color: ThemeColor.color100,
                      fontFamily: 'monospace',
                      fontSize: 11),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Done',
                    style: TextStyle(color: Color(0xFF9945FF))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) {
        CommonToast.instance.show(context, 'Transfer failed: $e');
      }
    } finally {
      setState(() => _isSending = false);
    }
  }
}
