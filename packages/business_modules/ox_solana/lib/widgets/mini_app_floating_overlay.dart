import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';

import '../services/mini_app_manager.dart';

class MiniAppFloatingOverlay extends StatefulWidget {
  final MiniAppSession session;
  const MiniAppFloatingOverlay({super.key, required this.session});

  @override
  State<MiniAppFloatingOverlay> createState() => _MiniAppFloatingOverlayState();
}

class _MiniAppFloatingOverlayState extends State<MiniAppFloatingOverlay> {
  double top = 120;
  double left = 12;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                top += details.delta.dy;
                left += details.delta.dx;
              });
            },
            onTap: () => MiniAppManager.instance.restore(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.px, vertical: 6.px),
              decoration: BoxDecoration(
                color: ThemeColor.color180.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ThemeColor.color160),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apps, color: ThemeColor.color0, size: 16),
                  SizedBox(width: 6.px),
                  Text(widget.session.title,
                      style: TextStyle(color: ThemeColor.color0, fontSize: 12)),
                  SizedBox(width: 6.px),
                  GestureDetector(
                    onTap: () => MiniAppManager.instance.close(),
                    child: Icon(Icons.close, color: ThemeColor.color110, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
