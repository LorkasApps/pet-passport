import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [address] in whatever maps app the device prefers. Uses the
/// Android `geo:0,0?q=…` intent (also handled by iOS via Apple Maps
/// fallback) so we do not hardcode Google Maps. On failure, shows a
/// snackbar with `l.launchFailed`.
Future<void> openInMaps(BuildContext context, String address) async {
  final l = AppL10n.of(context);
  final encoded = Uri.encodeComponent(address.trim());
  final uri = Uri.parse('geo:0,0?q=$encoded');
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.launchFailed)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.launchFailed)),
      );
    }
  }
}
