library ox_solana;

import 'package:flutter/material.dart';
import 'package:ox_common/navigator/navigator.dart';
import 'package:ox_module_service/ox_module_service.dart';

import 'services/solana_wallet_service.dart';
import 'services/tapestry_service.dart';
import 'services/price_service.dart';
import 'page/solana_wallet_page.dart';
import 'page/send_sol_page.dart';
import 'page/receive_page.dart';
import 'page/transaction_history_page.dart';
import 'page/swap_page.dart';
import 'services/chat_transfer_service.dart';

class OXSolana extends OXFlutterModule {
  static final OXSolana shared = OXSolana._();
  OXSolana._();
  factory OXSolana() => shared;

  @override
  String get moduleName => 'ox_solana';

  @override
  Future<void> setup() async {
    await super.setup();
    await SolanaWalletService.instance.init();
    await TapestryService.instance.init();
    // Pre-fetch token prices (non-blocking)
    PriceService.instance.fetchPrices();
  }

  @override
  Future<T?>? navigateToPage<T>(
      BuildContext context, String pageName, Map<String, dynamic>? params) {
    switch (pageName) {
      case 'SolanaWalletPage':
      case 'solanaWalletPage':
        return OXNavigator.pushPage(
            context, (ctx) => const SolanaWalletPage());
      case 'SendSolPage':
        return OXNavigator.pushPage(
            context,
            (ctx) => SendSolPage(
                  recipientAddress: params?['address'] ?? '',
                ));
      case 'ReceivePage':
        return OXNavigator.pushPage(context, (ctx) => const ReceivePage());
      case 'TransactionHistoryPage':
        return OXNavigator.pushPage(context, (ctx) => const TransactionHistoryPage());
      case 'SwapPage':
        return OXNavigator.pushPage(context, (ctx) => const SwapPage());
    }
    return null;
  }

  @override
  Map<String, Function> get interfaces => {
        'getSolanaAddress': () => SolanaWalletService.instance.address,
        'getSolBalance': () => SolanaWalletService.instance.balance,
        'hasSolanaWallet': () => SolanaWalletService.instance.hasWallet,
        'sendSol': ({required String toAddress, required double amount}) =>
            SolanaWalletService.instance
                .sendSol(toAddress: toAddress, amount: amount),
        // Widget interface for home tab bar embedding
        'solanaWalletPageWidget': (BuildContext context) =>
            const SolanaWalletPage(),
        // Tapestry identity resolution (for chat transfers)
        'resolveNostrToSolana': (String nostrPubkey) =>
            TapestryService.instance.resolveNostrToSolana(nostrPubkey),
        // Chat-integrated SOL transfer dialog
        'showSendSolDialog': (BuildContext context,
                {required String recipientNostrPubkey,
                String? recipientName}) =>
            ChatTransferService.showSendSolDialog(context,
                recipientNostrPubkey: recipientNostrPubkey,
                recipientName: recipientName),
      };
}
