import 'package:flutter/material.dart';
import 'package:ox_common/utils/theme_color.dart';

import '../services/mini_app_manager.dart';

/// Mini App container — provides WeChat-like shell for dapps
class MiniAppContainer extends StatefulWidget {
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final List<Widget>? actions;
  final MiniAppSession? session;
  final bool enableMinimize;

  const MiniAppContainer({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.actions,
    this.session,
    this.enableMinimize = true,
  });

  @override
  State<MiniAppContainer> createState() => _MiniAppContainerState();
}

class _MiniAppContainerState extends State<MiniAppContainer> {
  double _dragDistance = 0;
  bool _canDrag = false;
  bool _minimized = false;
  bool _showHint = false;

  void _minimizeIfNeeded() {
    if (_minimized) return;
    if (!widget.enableMinimize || widget.session == null) return;
    _minimized = true;
    MiniAppManager.instance.minimize(context, widget.session!);
  }

  @override
  Widget build(BuildContext context) {
    final body = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (details) {
        _canDrag = details.localPosition.dy < 80; // top swipe only
        _dragDistance = 0;
        if (_canDrag) {
          setState(() => _showHint = true);
        }
      },
      onVerticalDragUpdate: (details) {
        if (!_canDrag) return;
        if (details.delta.dy > 0) {
          _dragDistance += details.delta.dy;
          if (_dragDistance > 80) {
            _minimizeIfNeeded();
          } else {
            if (!_showHint) setState(() => _showHint = true);
          }
        }
      },
      onVerticalDragEnd: (_) {
        _dragDistance = 0;
        _canDrag = false;
        if (_showHint) setState(() => _showHint = false);
      },
      child: widget.child,
    );

    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: AppBar(
        backgroundColor: ThemeColor.color190,
        elevation: 0,
        title: Text(widget.title, style: TextStyle(color: ThemeColor.color0, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close, color: ThemeColor.color0),
          onPressed: widget.onClose ?? () => Navigator.pop(context),
        ),
        actions: [
          if (widget.enableMinimize && widget.session != null)
            IconButton(
              icon: Icon(Icons.minimize, color: ThemeColor.color0),
              onPressed: () => MiniAppManager.instance.minimize(context, widget.session!),
              tooltip: 'Minimize',
            ),
          ...?widget.actions,
        ],
      ),
      body: Stack(
        children: [
          body,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 150),
              opacity: _showHint ? 1.0 : 0.0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                color: ThemeColor.color180.withOpacity(0.9),
                child: Center(
                  child: Text('下拉最小化',
                      style: TextStyle(color: ThemeColor.color0, fontSize: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
