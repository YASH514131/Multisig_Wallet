import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValidBase58(String s) {
    if (s.length < 32 || s.length > 44) return false;
    final regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    return regex.hasMatch(s);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    // Try to extract a Solana public key from the scanned data
    // Handles plain pubkey or solana:<address> URIs
    String address = raw;
    if (address.startsWith('solana:')) {
      address = address.substring(7);
    }
    // Strip query params if any
    final qIndex = address.indexOf('?');
    if (qIndex > 0) address = address.substring(0, qIndex);

    address = address.trim();

    if (!_isValidBase58(address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Solana address in QR code')),
      );
      return;
    }

    setState(() => _scanned = true);
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay with cutout
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.brand, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Point camera at a Solana address QR code',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
