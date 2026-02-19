import 'package:flutter/material.dart';
import 'package:ox_common/utils/theme_color.dart';

/// Mini App container — provides WeChat-like shell for dapps
class MiniAppContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final List<Widget>? actions;

  const MiniAppContainer({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: AppBar(
        backgroundColor: ThemeColor.color190,
        elevation: 0,
        title: Text(title, style: TextStyle(color: ThemeColor.color0, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close, color: ThemeColor.color0),
          onPressed: onClose ?? () => Navigator.pop(context),
        ),
        actions: actions,
      ),
      body: child,
    );
  }
}
