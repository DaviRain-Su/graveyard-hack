import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

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
              // Network badge
              if (!SolanaWalletService.instance.isMainnet)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (SolanaWalletService.instance.isTestnet ? Colors.blueAccent : Colors.orange)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: (SolanaWalletService.instance.isTestnet ? Colors.blueAccent : Colors.orange)
                            .withOpacity(0.3)),
                  ),
                  child: Text(
                    '⚠️ ${SolanaWalletService.instance.networkName} address — test only',
                    style: TextStyle(
                        color: SolanaWalletService.instance.isTestnet
                            ? Colors.blueAccent
                            : Colors.orange,
                        fontSize: 12),
                  ),
                ),

              // QR Code with gradient border
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Adapt.px(20)),
                ),
                child: Container(
                  padding: EdgeInsets.all(Adapt.px(16)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Adapt.px(17)),
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
              ),
              SizedBox(height: Adapt.px(20)),

              Text(
                'Scan to send SOL to this address',
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

              // Copy + Share buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: address));
                        CommonToast.instance.show(context, 'Address copied!');
                      },
                      icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                      label: const Text('Copy',
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
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Share.share('My Solana address: $address');
                      },
                      icon: const Icon(Icons.share, color: Colors.white, size: 18),
                      label: const Text('Share',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14F195),
                        padding: EdgeInsets.symmetric(vertical: Adapt.px(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Adapt.px(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
