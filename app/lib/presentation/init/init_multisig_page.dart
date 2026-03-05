import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/config_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/multisig_client.dart';
import '../../services/solana_providers.dart';
import '../../services/wallet_controller.dart';
import '../../services/proposal_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class InitMultisigPage extends ConsumerStatefulWidget {
  const InitMultisigPage({super.key});

  @override
  ConsumerState<InitMultisigPage> createState() => _InitMultisigPageState();
}

class _InitMultisigPageState extends ConsumerState<InitMultisigPage> {
  final List<TextEditingController> _ownerControllers = [
    TextEditingController(),
  ];
  final _thresholdCtrl = TextEditingController(text: '1');
  bool _submitting = false;
  InitMultisigResult? _result;

  @override
  void initState() {
    super.initState();
    // Pre-fill first owner with current wallet address
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = ref.read(walletControllerProvider).valueOrNull;
      if (wallet != null && _ownerControllers.first.text.isEmpty) {
        _ownerControllers.first.text = wallet.address;
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ownerControllers) {
      c.dispose();
    }
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _addOwnerField() {
    if (_ownerControllers.length >= 10) {
      _showSnack('Maximum 10 owners');
      return;
    }
    setState(() => _ownerControllers.add(TextEditingController()));
  }

  void _removeOwnerField(int idx) {
    if (_ownerControllers.length <= 1) return;
    setState(() {
      _ownerControllers[idx].dispose();
      _ownerControllers.removeAt(idx);
    });
  }

  bool _isValidBase58(String s) {
    if (s.length < 32 || s.length > 44) return false;
    final regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    return regex.hasMatch(s);
  }

  Future<void> _initialize() async {
    final messenger = ScaffoldMessenger.of(context);

    // Collect and validate owners
    final owners = <String>[];
    for (int i = 0; i < _ownerControllers.length; i++) {
      final addr = _ownerControllers[i].text.trim();
      if (addr.isEmpty) {
        _showSnack('Owner ${i + 1} is empty');
        return;
      }
      if (!_isValidBase58(addr)) {
        _showSnack('Owner ${i + 1} is not a valid public key');
        return;
      }
      if (owners.contains(addr)) {
        _showSnack('Duplicate owner at position ${i + 1}');
        return;
      }
      owners.add(addr);
    }

    // Validate threshold
    final threshold = int.tryParse(_thresholdCtrl.text.trim());
    if (threshold == null || threshold < 1) {
      _showSnack('Threshold must be at least 1');
      return;
    }
    if (threshold > owners.length) {
      _showSnack('Threshold cannot exceed number of owners (${owners.length})');
      return;
    }

    // Check wallet
    final walletState = ref.read(walletControllerProvider).valueOrNull;
    if (walletState == null) {
      _showSnack('Load or create a wallet first');
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final client = ref.read(multisigClientProvider);

      // Build role mapping — all owners get BoardMember with 0 limit by default
      final roleMapping = owners
          .map((o) => RoleInputArgs(owner: o, roleIndex: 0, monthlyLimit: 0))
          .toList();

      final result = await client.initializeMultisigWithResult(
        owners: owners,
        threshold: threshold,
        roleMapping: roleMapping,
        wallet: ref.read(walletServiceProvider),
      );

      // Auto-configure the app with new multisig address
      await ref
          .read(appConfigProvider.notifier)
          .update(multisigAddress: result.multisigAddress);

      // Refresh providers
      ref.invalidate(balanceProvider);
      ref.invalidate(proposalsProvider);

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      setState(() {
        _submitting = false;
        _result = result;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Multisig wallet initialized successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Initialization failed: $e')),
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          'Initialize Multisig',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _result != null ? _buildSuccessView() : _buildForm(),
    );
  }

  Widget _buildSuccessView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // Success banner
        Container(
          padding: const EdgeInsets.all(20),
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
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Wallet Created!',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _resultRow('Multisig Address', _result!.multisigAddress),
              const SizedBox(height: 12),
              _resultRow('Vault Address', _result!.vaultAddress),
              const SizedBox(height: 12),
              _resultRow('Threshold', _thresholdCtrl.text.trim()),
              const SizedBox(height: 12),
              Text(
                'Owners',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              for (final c in _ownerControllers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    c.text.trim(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── QR Code for easy sharing ──
        Center(
          child: Column(
            children: [
              Text(
                'Share Multisig Address',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: Spacing.borderRadiusXl,
                  boxShadow: cardShadow,
                ),
                child: QrImageView(
                  data: _result!.multisigAddress,
                  version: QrVersions.auto,
                  size: 200,
                  gapless: true,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1a1a2e),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1a1a2e),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this QR to get the multisig address',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tx signature
        _resultRow('Transaction', _result!.txSignature),

        const SizedBox(height: 28),

        TactileButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_back_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Back to Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        _showSnack('$label copied');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.copy_rounded, size: 14, color: AppColors.brand),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Owners section ────────────────────────────────────────
        Text(
          'Owners',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Public keys of all multisig co-signers',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 12),

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
              for (int i = 0; i < _ownerControllers.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ownerControllers[i],
                        style: GoogleFonts.jetBrainsMono(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Owner ${i + 1}',
                          hintText: 'Base58 public key',
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_ownerControllers.length > 1)
                      IconButton(
                        onPressed: () => _removeOwnerField(i),
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 20,
                          color: AppColors.error,
                        ),
                        tooltip: 'Remove',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addOwnerField,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Owner'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Threshold ─────────────────────────────────────────────
        Text(
          'Threshold',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Number of approvals required to execute transactions',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: Spacing.borderRadiusLg,
            boxShadow: cardShadow,
            border: Border.all(color: AppColors.border.withAlpha(60)),
          ),
          child: TextField(
            controller: _thresholdCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.jetBrainsMono(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Approval threshold',
              hintText: '2',
              prefixIcon: Icon(Icons.how_to_vote_rounded, size: 20),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Submit ────────────────────────────────────────────────
        TactileButton(
          onPressed: _submitting ? null : _initialize,
          isLoading: _submitting,
          enabled: !_submitting,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_submitting)
                const Icon(Icons.rocket_launch_rounded, size: 18),
              if (!_submitting) const SizedBox(width: 8),
              Text(
                _submitting ? 'Initializing…' : 'Initialize Multisig',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        if (_submitting) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(Spacing.radiusFull),
            child: const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.brand,
              backgroundColor: AppColors.brandLight,
            ),
          ),
        ],
      ],
    );
  }
}
