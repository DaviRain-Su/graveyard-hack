import 'package:flutter/material.dart';
import 'package:ox_common/navigator/navigator.dart';
import 'package:ox_module_service/ox_module_service.dart';

import '../widgets/mini_app_floating_overlay.dart';

class MiniAppSession {
  final String module;
  final String pageName;
  final Map<String, dynamic>? params;
  final String title;

  MiniAppSession({
    required this.module,
    required this.pageName,
    required this.title,
    this.params,
  });
}

class MiniAppManager {
  static final MiniAppManager instance = MiniAppManager._();
  MiniAppManager._();

  OverlayEntry? overlayEntry;
  MiniAppSession? session;

  void minimize(BuildContext context, MiniAppSession session) {
    this.session = session;
    overlayEntry?.remove();
    overlayEntry = OverlayEntry(
      builder: (context) => MiniAppFloatingOverlay(session: session),
    );
    Overlay.of(OXNavigator.navigatorKey.currentContext!).insert(overlayEntry!);
    Navigator.pop(context);
  }

  void restore() {
    if (session == null) return;
    overlayEntry?.remove();
    overlayEntry = null;
    OXModuleService.pushPage(
      OXNavigator.navigatorKey.currentContext!,
      session!.module,
      session!.pageName,
      session!.params ?? {},
    );
  }

  void close() {
    overlayEntry?.remove();
    overlayEntry = null;
    session = null;
  }
}
