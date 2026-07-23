import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

/// Camera-based QR scanner for invite codes. Pops the token back to the
/// caller via `Navigator.pop(context, token)` — the join flow accepts a
/// nullable return so a user backing out is a no-op.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _returned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_returned) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      // Owner-side encodes the full deep link into the QR. Accept both
      // 'petpassport://invite/<token>' and a bare token in case someone
      // scans a plaintext QR generated elsewhere.
      final token = _extractToken(raw);
      if (token == null) continue;
      _returned = true;
      context.pop(token);
      return;
    }
  }

  static String? _extractToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'petpassport') {
      // path is '/invite/<token>' or authority='invite' + path='/<token>'
      final segments = uri.pathSegments.isEmpty
          ? <String>[uri.host, ...uri.pathSegments].where((s) => s.isNotEmpty).toList()
          : uri.pathSegments;
      if (segments.length >= 2 && segments.first == 'invite') {
        return segments[1];
      }
      if (uri.host == 'invite' && segments.isNotEmpty) {
        return segments.first;
      }
    }
    // Fallback: bare Base32 token pattern.
    if (RegExp(r'^[A-Z0-9-]{6,20}$', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.joinScanTitle)),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
