library ox_solana;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ox_common/navigator/navigator.dart';
import 'package:ox_common/const/common_constant.dart';
import 'package:ox_module_service/ox_module_service.dart';

import 'services/solana_wallet_service.dart';
import 'services/tapestry_service.dart';
import 'services/price_service.dart';
import 'services/red_packet_service.dart';
import 'page/solana_wallet_page.dart';
import 'page/send_sol_page.dart';
import 'page/receive_page.dart';
import 'page/transaction_history_page.dart';
import 'page/swap_page.dart';
import 'page/red_packet_page.dart';
import 'page/audius_page.dart';
import 'page/nft_gallery_page.dart';
import 'page/dapp_connect_page.dart';
import 'services/audius_service.dart';
import 'services/nft_service.dart';
import 'services/dapp_connect_service.dart';
import 'services/chat_transfer_service.dart';
import 'services/torque_service.dart';
import 'page/torque_quests_page.dart';
import 'services/kyd_service.dart';
import 'page/kyd_events_page.dart';
import 'widgets/floating_music_player.dart';

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
    await TapestryService.instance.init(
      apiKey: CommonConstant.tapestryApiKey, // From gitignored config
    );
    await RedPacketService.instance.init();
    await DappConnectService.instance.init();
    await TorqueService.instance.init();
    await KydService.instance.init();
    // Pre-fetch token prices (non-blocking)
    PriceService.instance.fetchPrices();

    // Auto-bind Tapestry profile when wallet is ready
    _autoBindTapestry();
    SolanaWalletService.instance.addListener(_autoBindTapestry);
  }

  void _autoBindTapestry() {
    final wallet = SolanaWalletService.instance;
    final tapestry = TapestryService.instance;
    if (wallet.hasWallet && !tapestry.hasBoundProfile && tapestry.hasApiKey) {
      final nostrPubkey = wallet.nostrPubkey;
      final username = nostrPubkey.isNotEmpty
          ? 'oxchat_${nostrPubkey.substring(0, 8)}'
          : 'oxchat_${wallet.address.substring(0, 8)}';
      tapestry.findOrCreateProfile(
        walletAddress: wallet.address,
        username: username,
        bio: '0xchat × Solana user',
        nostrPubkey: nostrPubkey.isNotEmpty ? nostrPubkey : null,
      ).then((_) {
        if (kDebugMode) print('[OXSolana] Auto-bound Tapestry profile: ${tapestry.profileId}');
      }).catchError((e) {
        if (kDebugMode) print('[OXSolana] Tapestry auto-bind failed: $e');
      });
    }
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
      case 'RedPacketPage':
        return OXNavigator.pushPage(
            context,
            (ctx) => RedPacketPage(
                  isGroup: params?['isGroup'] ?? false,
                  memberCount: params?['memberCount'],
                  onCreated: params?['onCreated'],
                ));
      case 'AudiusPage':
        final rawCallback = params?['onTrackSelected'];
        // Always wrap: convert AudiusTrack → Map<String,dynamic> at module boundary
        Function(AudiusTrack)? typedCallback;
        if (rawCallback != null) {
          typedCallback = (AudiusTrack track) {
            try {
              (rawCallback as Function)(track.toJson());
            } catch (e) {
              if (kDebugMode) print('[OXSolana] onTrackSelected callback error: $e');
            }
          };
        }
        return OXNavigator.pushPage(
            context,
            (ctx) => AudiusPage(
                  onTrackSelected: typedCallback,
                ));
      case 'NftGalleryPage':
        return OXNavigator.pushPage(context, (ctx) => NftGalleryPage(
          pickerMode: params?['pickerMode'] ?? false,
          onNftSelected: params?['onNftSelected'],
        ));
      case 'DappConnectPage':
        return OXNavigator.pushPage(context, (ctx) => const DappConnectPage());
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
        // Floating music player widget (for home scaffold overlay)
        'floatingMusicPlayer': () => const FloatingMusicPlayer(),
      };
}
