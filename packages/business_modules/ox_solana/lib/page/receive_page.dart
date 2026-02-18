import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/solana_wallet_service.dart';

class ReceivePage extends StatelessWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final address = SolanaWalletService.instance.address;

    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: 'Receive SOL',
        backgroundColor: ThemeColor.color190,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(Adapt.px(24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // QR Code
              Container(
                padding: EdgeInsets.all(Adapt.px(16)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Adapt.px(16)),
                ),
                child: QrImageView(
                  data: 'solana:$address',
                  size: Adapt.px(220),
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF9945FF),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: Adapt.px(24)),

              Text(
                'Scan to send SOL',
                style: TextStyle(color: ThemeColor.color100, fontSize: 14),
              ),
              SizedBox(height: Adapt.px(20)),

              // Full address
              Container(
                padding: EdgeInsets.all(Adapt.px(12)),
                decoration: BoxDecoration(
                  color: ThemeColor.color180,
                  borderRadius: BorderRadius.circular(Adapt.px(8)),
                ),
                child: SelectableText(
                  address,
                  style: TextStyle(
                    color: ThemeColor.color0,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: Adapt.px(16)),

              // Copy button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: address));
                    CommonToast.instance.show(context, 'Address copied!');
                  },
                  icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                  label: const Text('Copy Address',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9945FF),
                    padding: EdgeInsets.symmetric(vertical: Adapt.px(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Adapt.px(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
