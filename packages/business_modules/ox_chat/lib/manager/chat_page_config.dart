
import 'package:flutter/material.dart';
import 'package:ox_chat/widget/message_long_press_widget.dart';
import 'package:ox_chat/widget/reaction_input_widget.dart';
import 'package:ox_chat_ui/ox_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:chatcore/chat-core.dart';
import 'package:ox_chat/utils/general_handler/chat_general_handler.dart';
import 'package:ox_chat/utils/chat_log_utils.dart';
import 'package:ox_common/model/chat_type.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/platform_utils.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_image_gallery.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/business_interface/ox_chat/interface.dart';
import 'package:ox_localizable/ox_localizable.dart';
import 'package:ox_module_service/ox_module_service.dart';
import 'package:photo_view/photo_view.dart' show PhotoViewComputedScale;

class ChatPageConfig {

  static const messagesPerPage = 15;

  /// Menu item by message long pressed
  Widget longPressWidgetBuilder({
    required BuildContext context,
    required types.Message message,
    required CustomPopupMenuController controller,
    required ChatGeneralHandler handler,
  }) {
    return MessageLongPressWidget(
      pageContext: context,
      message: message,
      controller: controller,
      handler: handler,
    );
  }

  ImageGalleryOptions get imageGalleryOptions =>
      ImageGalleryOptions(
        maxScale: PhotoViewComputedScale.covered,
        minScale: PhotoViewComputedScale.contained,
      );

  List<InputMoreItem> inputMoreItemsWithHandler(ChatGeneralHandler handler) {
    bool isMobile = PlatformUtils.isMobile;
    final items = [
      InputMoreItemEx.album(handler),
      if(isMobile) InputMoreItemEx.camera(handler),
      if(isMobile) InputMoreItemEx.video(handler),
      InputMoreItemEx.ecash(handler),
      // SOL Red Packet — works in both group and single chats
      InputMoreItemEx.solRedPacket(handler),
      // Share NFT in chat
      InputMoreItemEx.shareNft(handler),
      // Share Audius music in chat
      InputMoreItemEx.shareMusic(handler),
      // Share KYD event in chat
      InputMoreItemEx.shareEvent(handler),
    ];

    final otherUser = handler.otherUser;
    if (handler.session.chatType == ChatType.chatSingle && otherUser != null) {
      items.add(InputMoreItemEx.zaps(handler, otherUser));
      // Send SOL — Solana wallet integration (1-on-1 only)
      items.add(InputMoreItemEx.sendSol(handler, otherUser));
      if(isMobile){
        items.add(InputMoreItemEx.call(handler, otherUser));
      }
    }

    return items;
  }

  ChatTheme get pageTheme =>
      DefaultChatTheme(
        sentMessageBodyTextStyle: TextStyle(
          color: ThemeColor.white,
          fontSize: Adapt.sp(16),
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        receivedMessageBodyTextStyle: TextStyle(
          color: ThemeColor.color0,
          fontSize: Adapt.sp(16),
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        inputTextColor: ThemeColor.color0,
      );
}

extension InputMoreItemEx on InputMoreItem {

  static InputMoreItem album(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'album',
        title: () => Localized.text('ox_chat_ui.input_more_album'),
        iconName: 'chat_photo_more.png',
        action: (context) {
          handler.albumPressHandler(context, 1);
        },
      );

  static InputMoreItem camera(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'camera',
        title: () => Localized.text('ox_chat_ui.input_more_camera'),
        iconName: 'chat_camera_more.png',
        action: (context) {
          handler.cameraPressHandler(context);
        },
      );

  static InputMoreItem video(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'video',
        title: () => Localized.text('ox_chat_ui.input_more_video'),
        iconName: 'chat_video_icon.png',
        action: (context) {
          handler.albumPressHandler(context, 2);
        },
      );

  static InputMoreItem call(ChatGeneralHandler handler, UserDBISAR? otherUser) =>
      InputMoreItem(
        id: 'call',
        title: () => Localized.text('ox_chat_ui.input_more_call'),
        iconName: 'chat_call_icon.png',
        action: (context) {
          final user = otherUser;
          if (user == null) {
            ChatLogUtils.error(className: 'ChatPageConfig', funcName: 'call', message: 'user is null');
            CommonToast.instance.show(context, 'User info not found');
            return ;
          }
          handler.callPressHandler(context, user);
        },
      );

  static InputMoreItem zaps(ChatGeneralHandler handler, UserDBISAR? otherUser) =>
      InputMoreItem(
        id: 'zaps',
        title: () => Localized.text('ox_chat_ui.input_more_zaps'),
        iconName: 'chat_zaps_icon.png',
        action: (context) {
          final user = otherUser;
          if (user == null) {
            ChatLogUtils.error(className: 'ChatPageConfig', funcName: 'zaps', message: 'user is null');
            CommonToast.instance.show(context, 'User info not found');
            return ;
          }
          handler.zapsPressHandler(context, user);
        },
      );

  static InputMoreItem ecash(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'ecash',
        title: () => Localized.text('ox_chat_ui.input_more_nuts'),
        iconName: 'chat_ecash_icon.png',
        action: (context) {
          handler.ecashPressHandler(context);
        },
      );

  /// Send SOL via Solana wallet — cross-module call to ox_solana
  static InputMoreItem sendSol(ChatGeneralHandler handler, UserDBISAR? otherUser) =>
      InputMoreItem(
        id: 'sendSol',
        title: () => 'SOL',
        iconName: 'chat_sol_icon.png',
        action: (context) {
          final user = otherUser;
          if (user == null) {
            ChatLogUtils.error(className: 'ChatPageConfig', funcName: 'sendSol', message: 'user is null');
            CommonToast.instance.show(context, 'User info not found');
            return;
          }

          // Check if ox_solana module has wallet
          final hasSolanaWallet = OXModuleService.invoke('ox_solana', 'hasSolanaWallet', []);
          if (hasSolanaWallet != true) {
            // No wallet — prompt to create one
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: ThemeColor.color180,
                title: Text('Solana Wallet Required', style: TextStyle(color: ThemeColor.color0)),
                content: Text(
                  'You need a Solana wallet to send SOL. Go to Me → Solana Wallet to create one.',
                  style: TextStyle(color: ThemeColor.color100),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      OXModuleService.pushPage(context, 'ox_solana', 'SolanaWalletPage', {});
                    },
                    child: Text('Go to Wallet', style: TextStyle(color: Color(0xFF9945FF), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            return;
          }

          // Call ox_solana's showSendSolDialog via module interface
          OXModuleService.invoke('ox_solana', 'showSendSolDialog', [
            context,
          ], {
            #recipientNostrPubkey: user.pubKey,
            #recipientName: user.name ?? user.pubKey.substring(0, 8),
          });
        },
      );

  /// SOL Red Packet 🧧 — send SOL red packets in any chat
  static InputMoreItem solRedPacket(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'solRedPacket',
        title: () => '🧧 SOL',
        iconName: 'chat_sol_icon.png',
        action: (context) {
          final hasSolanaWallet = OXModuleService.invoke('ox_solana', 'hasSolanaWallet', []);
          if (hasSolanaWallet != true) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: ThemeColor.color180,
                title: Text('Solana Wallet Required', style: TextStyle(color: ThemeColor.color0)),
                content: Text(
                  'Create a Solana wallet first to send red packets.',
                  style: TextStyle(color: ThemeColor.color100),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: ThemeColor.color100)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      OXModuleService.pushPage(context, 'ox_solana', 'SolanaWalletPage', {});
                    },
                    child: Text('Go to Wallet', style: TextStyle(color: Color(0xFF9945FF), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            return;
          }

          final isGroup = handler.session.hasMultipleUsers;
          OXModuleService.pushPage(context, 'ox_solana', 'RedPacketPage', {
            'isGroup': isGroup,
          });
        },
      );

  /// Share NFT — pick from wallet, send as rich link in chat
  static InputMoreItem shareNft(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'shareNft',
        title: () => 'NFT',
        iconName: 'chat_ecash_icon.png', // reuse icon
        action: (context) {
          final hasSolanaWallet = OXModuleService.invoke('ox_solana', 'hasSolanaWallet', []);
          if (hasSolanaWallet != true) {
            CommonToast.instance.show(context, 'Create a Solana wallet first');
            return;
          }

          // Open NFT gallery in picker mode → on pick, send as rich card
          OXModuleService.pushPage(context, 'ox_solana', 'NftGalleryPage', {
            'pickerMode': true,
            'onNftSelected': (Map<String, dynamic> nft) {
              final name = nft['name'] ?? 'NFT';
              final collection = nft['collection'] ?? '';
              final mint = nft['mint'] ?? '';
              final imageUrl = nft['imageUrl'] ?? '';
              final explorerUrl = 'https://explorer.solana.com/address/$mint';

              handler.sendTemplateMsg(
                context: context,
                title: '🖼️ $name',
                content: collection.isNotEmpty ? collection : 'Solana NFT • ${mint.substring(0, 8)}...',
                icon: imageUrl,
                link: explorerUrl,
              );
            },
          });
        },
      );

  /// Share Audius music — pick trending or search, send as rich link
  static InputMoreItem shareMusic(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'shareMusic',
        title: () => '🎵 Music',
        iconName: 'chat_more_icon.png', // reuse icon
        action: (context) {
          // Open Audius in picker mode → on pick, send as rich card
          OXModuleService.pushPage(context, 'ox_solana', 'AudiusPage', {
            'onTrackSelected': (dynamic track) {
              Map<String, dynamic> trackMap;
              if (track is Map<String, dynamic>) {
                trackMap = track;
              } else if (track is Map) {
                trackMap = Map<String, dynamic>.from(track);
              } else {
                trackMap = {};
              }

              final title = trackMap['title'] ?? 'Track';
              final artist = trackMap['artist'] ?? '';
              final shareUrl = trackMap['share_url'] ?? '';
              final artworkUrl = trackMap['artwork_url'] ?? '';

              handler.sendTemplateMsg(
                context: context,
                title: '🎵 $title',
                content: 'by $artist',
                icon: artworkUrl,
                link: shareUrl,
              );
            },
          });
        },
      );

  static InputMoreItem shareEvent(ChatGeneralHandler handler) =>
      InputMoreItem(
        id: 'shareEvent',
        title: () => '🎫 Event',
        iconName: 'chat_more_icon.png',
        action: (context) {
          OXModuleService.pushPage(context, 'ox_solana', 'KydEventsPage', {
            'onEventSelected': (dynamic event) {
              Map<String, dynamic> eventMap;
              if (event is Map<String, dynamic>) {
                eventMap = event;
              } else if (event is Map) {
                eventMap = Map<String, dynamic>.from(event);
              } else {
                eventMap = {};
              }

              final name = eventMap['name'] ?? 'Event';
              final date = eventMap['display_start_at'] ?? '';
              final venue = eventMap['venue_name'] ?? '';
              final url = eventMap['share_url'] ?? '';
              final imageUrl = eventMap['image_url'] ?? '';

              handler.sendTemplateMsg(
                context: context,
                title: '🎫 $name',
                content: '📅 $date\n📍 $venue',
                icon: imageUrl,
                link: url,
              );
            },
          });
        },
      );

}
