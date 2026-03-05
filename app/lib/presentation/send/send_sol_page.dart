import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/solana_providers.dart';
import '../../services/wallet_controller.dart';
import '../../shared/widgets/common_widgets.dart';
import '../qr/qr_display_page.dart';
import '../qr/qr_scanner_page.dart';

class SendSolPage extends ConsumerStatefulWidget {
  const SendSolPage({super.key});

  @override
  ConsumerState<SendSolPage> createState() => _SendSolPageState();
}

class _SendSolPageState extends ConsumerState<SendSolPage> {
  final _recipientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _sending = false;
  String? _txHash;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool _isValidBase58(String s) {
    if (s.length < 32 || s.length > 44) return false;
    final regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    return regex.hasMatch(s);
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    final recipient = _recipientCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    final wallet = ref.read(walletControllerProvider).valueOrNull;

    if (wallet == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No wallet loaded')));
      return;
    }

    if (recipient.isEmpty || !_isValidBase58(recipient)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid recipient public key')),
      );
      return;
    }

    if (recipient == wallet.address) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cannot send to yourself')),
      );
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than 0')),
      );
      return;
    }

    final lamports = (amount * lamportsPerSol).round();

    // Check balance
    try {
      final balance = await ref.read(balanceProvider.future);
      if (amount > balance) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient balance (${balance.toStringAsFixed(4)} SOL)',
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // If we can't check balance, proceed anyway — chain will reject
    }

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      final client = ref.read(multisigClientProvider);
      final txSig = await client.sendSol(
        recipient: recipient,
        lamports: lamports,
        wallet: ref.read(walletServiceProvider),
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      setState(() {
        _sending = false;
        _txHash = txSig;
      });

      ref.invalidate(balanceProvider);

      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction sent successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (result != null && result.isNotEmpty) {
      _recipientCtrl.text = result;
    }
  }

  void _showMyQr() {
    final wallet = ref.read(walletControllerProvider).valueOrNull;
    if (wallet == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QrDisplayPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Send SOL',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _showMyQr,
              icon: const Icon(
                Icons.qr_code_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'My QR Code',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Info banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: Spacing.borderRadiusMd,
              border: Border.all(color: AppColors.info.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This sends SOL directly from your wallet — not from the multisig vault.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.info,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Recipient ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: Spacing.borderRadiusLg,
              boxShadow: cardShadow,
              border: Border.all(color: AppColors.border.withAlpha(60)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _recipientCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Recipient Address',
                    hintText: 'Base58 public key',
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      onPressed: _scanQr,
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                        color: AppColors.brand,
                      ),
                      tooltip: 'Scan QR',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Amount (SOL)',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.toll_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Send button ──────────────────────────────────────────
          TactileButton(
            onPressed: _sending ? null : _send,
            isLoading: _sending,
            enabled: !_sending,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_sending) const Icon(Icons.send_rounded, size: 18),
                if (!_sending) const SizedBox(width: 8),
                Text(
                  _sending ? 'Sending…' : 'Send SOL',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Tx result ────────────────────────────────────────────
          if (_txHash != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: Spacing.borderRadiusLg,
                border: Border.all(color: AppColors.success.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Transaction Sent',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Signature',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _txHash!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tx hash copied')),
                      );
                    },
                    child: Text(
                      _txHash!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'View on Solana Explorer ↗',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
