import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ox_common/business_interface/ox_chat/interface.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';

import 'solana_wallet_service.dart';
import 'tapestry_service.dart';

/// Chat-integrated SOL transfer service — enables sending SOL within 0xchat conversations.
/// Uses Nostr template messages to communicate transfer info.
class ChatTransferService {
  static final ChatTransferService instance = ChatTransferService._();
  ChatTransferService._();

  /// Show send-SOL dialog within a chat context
  static Future<void> showSendSolDialog(
    BuildContext context, {
    required String recipientNostrPubkey,
    String? recipientName,
  }) async {
    final wallet = SolanaWalletService.instance;

    if (!wallet.hasWallet) {
      CommonToast.instance.show(context, 'Create a Solana wallet first');
      return;
    }

    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send, color: Colors.white, size: 14),
            ),
            SizedBox(width: 10),
            Text('Send SOL', style: TextStyle(color: ThemeColor.color0)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To: ${recipientName ?? _shortPubkey(recipientNostrPubkey)}',
              style: TextStyle(color: ThemeColor.color100, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Balance: ${wallet.balance.toStringAsFixed(4)} SOL',
              style: TextStyle(color: ThemeColor.color100, fontSize: 12),
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: ThemeColor.color0, fontSize: 24),
              decoration: InputDecoration(
                hintText: '0.0',
                hintStyle: TextStyle(color: ThemeColor.color110),
                suffixText: 'SOL',
                suffixStyle: TextStyle(color: ThemeColor.color100),
                filled: true,
                fillColor: ThemeColor.color190,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
            onPressed: () async {
              final amountStr = amountController.text.trim();
              final amount = double.tryParse(amountStr);
              if (amount == null || amount <= 0) {
                CommonToast.instance.show(context, 'Enter valid amount');
                return;
              }
              if (amount > wallet.balance) {
                CommonToast.instance.show(context, 'Insufficient balance');
                return;
              }
              Navigator.pop(ctx);

              await _executeChatTransfer(
                context,
                recipientNostrPubkey: recipientNostrPubkey,
                recipientName: recipientName,
                amount: amount,
              );
            },
            child: Text('Send', style: TextStyle(color: Color(0xFF9945FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Execute transfer: resolve address → send SOL → send chat message
  static Future<void> _executeChatTransfer(
    BuildContext context, {
    required String recipientNostrPubkey,
    String? recipientName,
    required double amount,
  }) async {
    final wallet = SolanaWalletService.instance;

    try {
      OXLoading.show();

      // 1. Resolve recipient's Solana address via Tapestry
      String? recipientSolAddress = await TapestryService.instance
          .resolveNostrToSolana(recipientNostrPubkey);

      if (recipientSolAddress == null) {
        OXLoading.dismiss();
        if (context.mounted) {
          // Offer to enter address manually
          final manualAddress = await _showManualAddressDialog(
            context,
            recipientName: recipientName,
          );
          if (manualAddress == null || manualAddress.isEmpty) return;
          recipientSolAddress = manualAddress;

          // Cache this binding for future transfers
          await TapestryService.instance.bindLocal(
            nostrPubkey: recipientNostrPubkey,
            solanaAddress: recipientSolAddress,
          );
          OXLoading.show();
        } else {
          return;
        }
      }

      // 2. Send SOL
      final signature = await wallet.sendSol(
        toAddress: recipientSolAddress,
        amount: amount,
      );

      OXLoading.dismiss();

      // 3. Send template message in chat (notify recipient)
      final transferData = {
        'type': 'sol_transfer',
        'amount': amount.toString(),
        'signature': signature,
        'from_address': wallet.address,
        'to_address': recipientSolAddress,
        'network': wallet.isDevnet ? 'devnet' : 'mainnet',
      };

      OXChatInterface.sendTemplateMessage(
        context,
        receiverPubkey: recipientNostrPubkey,
        title: '💸 SOL Transfer',
        subTitle: '${amount.toStringAsFixed(4)} SOL sent',
        link: 'solana:tx:$signature',
      );

      if (context.mounted) {
        CommonToast.instance.show(context, 'Sent ${amount.toStringAsFixed(4)} SOL! ✅');
      }
    } catch (e) {
      OXLoading.dismiss();
      if (context.mounted) {
        CommonToast.instance.show(context, 'Transfer failed: $e');
      }
    }
  }

  /// Create a SOL transfer message payload (for custom message types)
  static Map<String, dynamic> createTransferPayload({
    required double amount,
    required String signature,
    required String fromAddress,
    required String toAddress,
    bool isDevnet = false,
  }) {
    return {
      'type': 'sol_transfer',
      'amount': amount.toString(),
      'signature': signature,
      'from_address': fromAddress,
      'to_address': toAddress,
      'network': isDevnet ? 'devnet' : 'mainnet',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Parse incoming transfer message
  static SolTransferMessage? parseTransferMessage(String content) {
    try {
      final data = jsonDecode(content);
      if (data['type'] == 'sol_transfer') {
        return SolTransferMessage(
          amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0,
          signature: data['signature'] ?? '',
          fromAddress: data['from_address'] ?? '',
          toAddress: data['to_address'] ?? '',
          isDevnet: data['network'] == 'devnet',
        );
      }
    } catch (_) {}
    return null;
  }

  /// Show dialog to enter recipient's Solana address manually
  static Future<String?> _showManualAddressDialog(
    BuildContext context, {
    String? recipientName,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColor.color180,
        title: Text(
          'Enter Solana Address',
          style: TextStyle(color: ThemeColor.color0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${recipientName ?? "This contact"} hasn\'t linked a Solana wallet yet.\n\nPaste their Solana address to send directly:',
              style: TextStyle(color: ThemeColor.color100, fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              style: TextStyle(color: ThemeColor.color0, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Solana address...',
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
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
          ),
          TextButton(
            onPressed: () {
              final addr = controller.text.trim();
              if (SolanaWalletService.isValidSolanaAddress(addr)) {
                Navigator.pop(ctx, addr);
              } else {
                CommonToast.instance.show(context, 'Invalid Solana address');
              }
            },
            child: Text('Confirm', style: TextStyle(color: Color(0xFF9945FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _shortPubkey(String pubkey) {
    if (pubkey.length < 16) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }
}

/// Parsed SOL transfer message
class SolTransferMessage {
  final double amount;
  final String signature;
  final String fromAddress;
  final String toAddress;
  final bool isDevnet;

  const SolTransferMessage({
    required this.amount,
    required this.signature,
    required this.fromAddress,
    required this.toAddress,
    this.isDevnet = false,
  });

  String get explorerUrl {
    final cluster = isDevnet ? '?cluster=devnet' : '';
    return 'https://explorer.solana.com/tx/$signature$cluster';
  }
}
