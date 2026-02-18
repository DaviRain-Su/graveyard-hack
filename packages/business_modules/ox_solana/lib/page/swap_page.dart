import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_common/widgets/common_loading.dart';

import '../services/jupiter_service.dart';
import '../services/solana_wallet_service.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  final _amountController = TextEditingController();
  SwapToken _inputToken = JupiterService.popularTokens[0]; // SOL
  SwapToken _outputToken = JupiterService.popularTokens[1]; // USDC
  JupiterQuote? _quote;
  bool _isQuoting = false;
  bool _isSwapping = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.color190,
      appBar: CommonAppBar(
        title: 'Swap',
        backgroundColor: ThemeColor.color190,
      ),
      body: Padding(
        padding: EdgeInsets.all(Adapt.px(16)),
        child: Column(
          children: [
            // Input token
            _buildTokenInput(
              label: 'You Pay',
              token: _inputToken,
              controller: _amountController,
              onTokenTap: () => _selectToken(isInput: true),
              editable: true,
            ),
            SizedBox(height: Adapt.px(4)),

            // Swap direction button
            Center(
              child: GestureDetector(
                onTap: _swapDirection,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9945FF).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.swap_vert, color: const Color(0xFF9945FF), size: 24),
                ),
              ),
            ),
            SizedBox(height: Adapt.px(4)),

            // Output token
            _buildTokenOutput(),
            SizedBox(height: Adapt.px(16)),

            // Quote button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isQuoting ? null : _getQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColor.color180,
                  padding: EdgeInsets.symmetric(vertical: Adapt.px(14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isQuoting
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF9945FF)))
                    : Text('Get Quote', style: TextStyle(color: const Color(0xFF9945FF), fontSize: 16)),
              ),
            ),
            SizedBox(height: Adapt.px(12)),

            // Quote info
            if (_quote != null) _buildQuoteInfo(),

            const Spacer(),

            // Swap button
            if (_quote != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSwapping ? null : _executeSwap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9945FF),
                    padding: EdgeInsets.symmetric(vertical: Adapt.px(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSwapping
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Swap', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

            // Mainnet warning
            if (!SolanaWalletService.instance.isDevnet) ...[
              SizedBox(height: 8),
              Text(
                '⚠️ Swaps are on Mainnet — real funds',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
            SizedBox(height: Adapt.px(16)),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenInput({
    required String label,
    required SwapToken token,
    required TextEditingController controller,
    required VoidCallback onTokenTap,
    required bool editable,
  }) {
    return Container(
      padding: EdgeInsets.all(Adapt.px(16)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
              if (editable) _buildTokenBalance(token),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ThemeColor.color0, fontSize: 28, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0.0',
                    hintStyle: TextStyle(color: ThemeColor.color110),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) {
                    // Clear quote when amount changes
                    if (_quote != null) setState(() => _quote = null);
                  },
                ),
              ),
              GestureDetector(
                onTap: onTokenTap,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeColor.color190,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tokenIcon(token, size: 24),
                      SizedBox(width: 6),
                      Text(token.symbol, style: TextStyle(color: ThemeColor.color0, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18, color: ThemeColor.color100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenOutput() {
    final outAmount = _quote != null
        ? _quote!.outAmountDisplay(_outputToken.decimals)
        : '—';

    return Container(
      padding: EdgeInsets.all(Adapt.px(16)),
      decoration: BoxDecoration(
        color: ThemeColor.color180,
        borderRadius: BorderRadius.circular(Adapt.px(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You Receive', style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  outAmount,
                  style: TextStyle(
                    color: _quote != null ? ThemeColor.color0 : ThemeColor.color110,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _selectToken(isInput: false),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeColor.color190,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tokenIcon(_outputToken, size: 24),
                      SizedBox(width: 6),
                      Text(_outputToken.symbol, style: TextStyle(color: ThemeColor.color0, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18, color: ThemeColor.color100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenBalance(SwapToken token) {
    final wallet = SolanaWalletService.instance;
    String bal = '—';

    if (token.mint == JupiterService.solMint) {
      bal = wallet.balance.toStringAsFixed(4);
    } else {
      // Look up SPL token balance
      final match = wallet.tokens.where((t) => t.mintAddress == token.mint);
      if (match.isNotEmpty) {
        bal = match.first.balanceDisplay;
      } else {
        bal = '0';
      }
    }

    return GestureDetector(
      onTap: () {
        _amountController.text = bal;
        if (_quote != null) setState(() => _quote = null);
      },
      child: Text(
        'Bal: $bal',
        style: TextStyle(color: ThemeColor.color100, fontSize: 12),
      ),
    );
  }

  Widget _buildQuoteInfo() {
    return Container(
      padding: EdgeInsets.all(Adapt.px(12)),
      decoration: BoxDecoration(
        color: ThemeColor.color180.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _quoteRow('Rate', '1 ${_inputToken.symbol} ≈ ${_calcRate()} ${_outputToken.symbol}'),
          SizedBox(height: 6),
          _quoteRow('Price Impact', '${_quote!.priceImpactPct.toStringAsFixed(4)}%'),
          SizedBox(height: 6),
          _quoteRow('Route', '${_quote!.routePlan.length} hop(s)'),
        ],
      ),
    );
  }

  Widget _quoteRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: ThemeColor.color100, fontSize: 13)),
        Text(value, style: TextStyle(color: ThemeColor.color0, fontSize: 13)),
      ],
    );
  }

  Widget _tokenIcon(SwapToken token, {double size = 32}) {
    final colors = {
      'SOL': const Color(0xFF9945FF),
      'USDC': const Color(0xFF2775CA),
      'USDT': const Color(0xFF50AF95),
      'BONK': const Color(0xFFF9A825),
      'JUP': const Color(0xFF14F195),
    };
    final color = colors[token.symbol] ?? const Color(0xFF9945FF);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          token.logoChar,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.5),
        ),
      ),
    );
  }

  String _calcRate() {
    if (_quote == null) return '—';
    final inAmt = int.tryParse(_quote!.inAmount) ?? 0;
    final outAmt = int.tryParse(_quote!.outAmount) ?? 0;
    if (inAmt == 0) return '—';
    final inDec = inAmt / math.pow(10, _inputToken.decimals);
    final outDec = outAmt / math.pow(10, _outputToken.decimals);
    return (outDec / inDec).toStringAsFixed(4);
  }

  void _swapDirection() {
    setState(() {
      final tmp = _inputToken;
      _inputToken = _outputToken;
      _outputToken = tmp;
      _quote = null;
    });
  }

  /// Build combined token list: popular tokens + wallet's SPL tokens
  List<SwapToken> _buildTokenList() {
    final popular = List<SwapToken>.from(JupiterService.popularTokens);
    final walletTokens = SolanaWalletService.instance.tokens;
    final popularMints = popular.map((t) => t.mint).toSet();

    // Add wallet tokens not already in popular list
    for (final wt in walletTokens) {
      if (!popularMints.contains(wt.mintAddress)) {
        popular.add(SwapToken(
          symbol: wt.symbol,
          name: wt.symbol,
          mint: wt.mintAddress,
          decimals: wt.decimals,
          logoChar: wt.symbol.isNotEmpty ? wt.symbol[0] : '?',
        ));
      }
    }
    return popular;
  }

  void _selectToken({required bool isInput}) {
    final allTokens = _buildTokenList();

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColor.color190,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        builder: (ctx, scrollController) => Padding(
          padding: EdgeInsets.all(Adapt.px(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Token',
                style: TextStyle(color: ThemeColor.color0, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: allTokens.length,
                  itemBuilder: (ctx, i) {
                    final token = allTokens[i];
                    final isSelected = isInput
                        ? token.mint == _inputToken.mint
                        : token.mint == _outputToken.mint;
                    return ListTile(
                      leading: _tokenIcon(token),
                      title: Text(token.symbol, style: TextStyle(color: ThemeColor.color0, fontWeight: FontWeight.w600)),
                      subtitle: Text(token.name, style: TextStyle(color: ThemeColor.color100, fontSize: 12)),
                      trailing: isSelected ? Icon(Icons.check, color: const Color(0xFF14F195)) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          if (isInput) {
                            _inputToken = token;
                            if (_outputToken.mint == token.mint) {
                              _outputToken = allTokens.firstWhere((t) => t.mint != token.mint, orElse: () => JupiterService.popularTokens[1]);
                            }
                          } else {
                            _outputToken = token;
                            if (_inputToken.mint == token.mint) {
                              _inputToken = allTokens.firstWhere((t) => t.mint != token.mint, orElse: () => JupiterService.popularTokens[0]);
                            }
                          }
                          _quote = null;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getQuote() async {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      CommonToast.instance.show(context, 'Enter an amount');
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      CommonToast.instance.show(context, 'Invalid amount');
      return;
    }

    setState(() => _isQuoting = true);

    final rawAmount = (amount * math.pow(10, _inputToken.decimals)).toInt();
    final quote = await JupiterService.instance.getQuote(
      inputMint: _inputToken.mint,
      outputMint: _outputToken.mint,
      amount: rawAmount,
    );

    setState(() {
      _isQuoting = false;
      _quote = quote;
    });

    if (quote == null && mounted) {
      CommonToast.instance.show(context, 'No route found');
    }
  }

  Future<void> _executeSwap() async {
    if (_quote == null) return;

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;
    final rawAmount = (amount * math.pow(10, _inputToken.decimals)).toInt();

    setState(() => _isSwapping = true);

    try {
      OXLoading.show();
      final signature = await JupiterService.instance.executeSwap(
        inputMint: _inputToken.mint,
        outputMint: _outputToken.mint,
        amount: rawAmount,
      );
      OXLoading.dismiss();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThemeColor.color180,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF14F195), size: 28),
                SizedBox(width: 8),
                Text('Swap Complete!', style: TextStyle(color: ThemeColor.color0)),
              ],
            ),
            content: Text(
              'Swapped ${_quote!.inAmountDisplay(_inputToken.decimals)} ${_inputToken.symbol} → ${_quote!.outAmountDisplay(_outputToken.decimals)} ${_outputToken.symbol}',
              style: TextStyle(color: ThemeColor.color0),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text('Done', style: TextStyle(color: Color(0xFF9945FF))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      OXLoading.dismiss();
      if (mounted) {
        CommonToast.instance.show(context, 'Swap failed: $e');
      }
    } finally {
      setState(() => _isSwapping = false);
    }
  }
}
