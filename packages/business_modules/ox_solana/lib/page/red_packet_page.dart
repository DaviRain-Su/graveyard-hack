import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';

import '../services/solana_wallet_service.dart';
import '../services/red_packet_service.dart';

/// Red packet creation page — send SOL 红包 in chats
class RedPacketPage extends StatefulWidget {
  final bool isGroup;
  final int? memberCount;
  final Function(RedPacket packet)? onCreated;

  const RedPacketPage({
    super.key,
    this.isGroup = false,
    this.memberCount,
    this.onCreated,
  });

  @override
  State<RedPacketPage> createState() => _RedPacketPageState();
}

class _RedPacketPageState extends State<RedPacketPage> {
  final _amountController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _messageController = TextEditingController();

  RedPacketType _type = RedPacketType.random;
  bool _isCreating = false;

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  int get _count => int.tryParse(_countController.text) ?? 1;
  double get _balance => SolanaWalletService.instance.balance;

  @override
  void initState() {
    super.initState();
    if (!widget.isGroup) {
      _countController.text = '1';
      _type = RedPacketType.equal;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _countController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: '🧧 Send Red Packet',
        backgroundColor: ThemeColor.color190,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Adapt.px(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Red packet header
            _buildHeader(),
            SizedBox(height: Adapt.px(24)),

            // Type selector (group only)
            if (widget.isGroup) ...[
              _buildTypeSelector(),
              SizedBox(height: Adapt.px(16)),
            ],

            // Amount input
            _buildAmountInput(),
            SizedBox(height: Adapt.px(16)),

            // Count input (group only)
            if (widget.isGroup) _buildCountInput(),
            if (widget.isGroup) SizedBox(height: Adapt.px(16)),

            // Message input
            _buildMessageInput(),
            SizedBox(height: Adapt.px(8)),

            // Summary
            _buildSummary(),
            SizedBox(height: Adapt.px(32)),

            // Send button
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(Adapt.px(20)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE74C3C), Color(0xFFF39C12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text('🧧', style: TextStyle(fontSize: 40)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isGroup ? 'Group Red Packet' : 'Red Packet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.isGroup
                      ? 'Send SOL to group members'
                      : 'Send SOL as a gift',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTypeOption(RedPacketType.random, '🎲 Random', 'Lucky draw amounts'),
          SizedBox(width: 4),
          _buildTypeOption(RedPacketType.equal, '⚖️ Equal', 'Same amount each'),
        ],
      ),
    );
  }

  Widget _buildTypeOption(RedPacketType type, String label, String desc) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFE74C3C).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: Color(0xFFE74C3C).withOpacity(0.3)) : null,
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(
                color: isSelected ? Color(0xFFE74C3C) : ThemeColor.color100,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
              SizedBox(height: 2),
              Text(desc, style: TextStyle(color: ThemeColor.color110, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isGroup && _type == RedPacketType.equal
                    ? 'Amount per person'
                    : 'Total Amount',
                style: TextStyle(color: ThemeColor.color100, fontSize: 13),
              ),
              GestureDetector(
                onTap: () {
                  final maxAmount = math.max(0.0, _balance - 0.01);
                  _amountController.text = maxAmount.toStringAsFixed(4);
                  setState(() {});
                },
                child: Text(
                  'Bal: ${_balance.toStringAsFixed(4)} SOL',
                  style: TextStyle(color: const Color(0xFF9945FF), fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: ThemeColor.color0, fontSize: 28, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: TextStyle(color: ThemeColor.color110),
              suffixText: 'SOL',
              suffixStyle: TextStyle(color: ThemeColor.color100, fontSize: 16),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Number of packets',
                style: TextStyle(color: ThemeColor.color100, fontSize: 14)),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeColor.color0, fontSize: 20, fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _messageController,
        style: TextStyle(color: ThemeColor.color0, fontSize: 14),
        maxLines: 2,
        decoration: InputDecoration(
          hintText: '恭喜发财，大吉大利！',
          hintStyle: TextStyle(color: ThemeColor.color110),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          prefixIcon: Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('💬', style: TextStyle(fontSize: 18)),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final totalAmount = _type == RedPacketType.equal && widget.isGroup
        ? _amount * _count
        : _amount;
    final perPerson = widget.isGroup && _type == RedPacketType.random && _count > 0
        ? '~${(totalAmount / _count).toStringAsFixed(4)}'
        : _amount.toStringAsFixed(4);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColor.color180.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _summaryRow('Total', '${totalAmount.toStringAsFixed(4)} SOL'),
          if (widget.isGroup) _summaryRow('Packets', '$_count'),
          if (widget.isGroup) _summaryRow(
            _type == RedPacketType.random ? 'Avg per person' : 'Per person',
            '$perPerson SOL',
          ),
          _summaryRow('Network', SolanaWalletService.instance.networkName),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
          Text(value, style: TextStyle(color: ThemeColor.color0, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final totalAmount = _type == RedPacketType.equal && widget.isGroup
        ? _amount * _count
        : _amount;
    final canSend = totalAmount > 0 && _count > 0 && totalAmount <= _balance - 0.01;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSend && !_isCreating ? _createRedPacket : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE74C3C),
          disabledBackgroundColor: ThemeColor.color180,
          padding: EdgeInsets.symmetric(vertical: Adapt.px(16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isCreating
            ? SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                '🧧 Send Red Packet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _createRedPacket() async {
    HapticFeedback.lightImpact();
    final totalAmount = _type == RedPacketType.equal && widget.isGroup
        ? _amount * _count
        : _amount;

    setState(() => _isCreating = true);

    try {
      final packet = RedPacketService.instance.createRedPacket(
        totalAmount: totalAmount,
        count: _count,
        type: _type,
        message: _messageController.text.isNotEmpty
            ? _messageController.text
            : null,
      );

      widget.onCreated?.call(packet);

      if (mounted) {
        // Show success and pop
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThemeColor.color180,
            title: Row(
              children: [
                Text('🧧', style: TextStyle(fontSize: 28)),
                SizedBox(width: 8),
                Text('Red Packet Created!', style: TextStyle(color: ThemeColor.color0, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${totalAmount.toStringAsFixed(4)} SOL × $_count packet(s)',
                    style: TextStyle(color: ThemeColor.color100)),
                SizedBox(height: 4),
                Text('"${packet.message}"',
                    style: TextStyle(color: ThemeColor.color100, fontStyle: FontStyle.italic)),
                SizedBox(height: 8),
                Text('The red packet message will be sent in chat.',
                    style: TextStyle(color: ThemeColor.color110, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text('Done', style: TextStyle(color: Color(0xFFE74C3C), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CommonToast.instance.show(context, '$e');
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }
}
