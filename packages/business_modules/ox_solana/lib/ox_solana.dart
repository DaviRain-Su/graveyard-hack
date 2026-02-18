library ox_solana;

import 'package:flutter/material.dart';
import 'package:ox_common/navigator/navigator.dart';
import 'package:ox_module_service/ox_module_service.dart';

import 'services/solana_wallet_service.dart';
import 'page/solana_wallet_page.dart';
import 'page/send_sol_page.dart';
import 'page/receive_page.dart';

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
  }

  @override
  Future<T?>? navigateToPage<T>(
      BuildContext context, String pageName, Map<String, dynamic>? params) {
    switch (pageName) {
      case 'SolanaWalletPage':
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
      };
}
