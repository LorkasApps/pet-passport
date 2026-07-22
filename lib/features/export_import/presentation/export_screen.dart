import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:share_plus/share_plus.dart';

import '../application/export_providers.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;
  String? _lastError;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _lastError = null;
    });
    try {
      final service = ref.read(exportServiceProvider);
      final file = await service.writeSnapshotToTempFile();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Pet Passport Export',
      );
    } catch (e) {
      setState(() => _lastError = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.exportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.download_outlined, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.exportJsonTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.exportJsonHelp,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share),
                      label: Text(l.exportJsonAction),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_lastError != null) ...[
            const SizedBox(height: 12),
            Card(
              color: scheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: scheme.onErrorContainer),
                title: Text(
                  _lastError!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.exportMediaNote,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
