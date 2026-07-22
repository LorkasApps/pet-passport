import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/vets_providers.dart';
import '../domain/vet.dart';

class VetDetailScreen extends ConsumerWidget {
  const VetDetailScreen({
    super.key,
    required this.petUuid,
    required this.vetUuid,
  });

  final String petUuid;
  final String vetUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      vetByUuidProvider((vetUuid: vetUuid, petUuid: petUuid)),
    );
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (vet) {
        if (vet == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('—')),
          );
        }
        return _VetDetailContent(vet: vet, petUuid: petUuid);
      },
    );
  }
}

class _VetDetailContent extends StatelessWidget {
  const _VetDetailContent({required this.vet, required this.petUuid});

  final Vet vet;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(vet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l.actionEdit,
            onPressed: () =>
                context.push('/pets/$petUuid/vets/${vet.uuid}/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (vet.practice != null && vet.practice!.isNotEmpty)
            _readOnlyTile(
              context: context,
              icon: Icons.medical_services_outlined,
              label: l.vetFieldPractice,
              value: vet.practice!,
            ),
          if (vet.phone != null && vet.phone!.isNotEmpty)
            _actionTile(
              context: context,
              icon: Icons.phone_outlined,
              label: l.vetFieldPhone,
              value: vet.phone!,
              onTap: () => _callNumber(context, vet.phone!),
              onLongPress: () => _copy(context, vet.phone!, l),
            ),
          if (vet.email != null && vet.email!.isNotEmpty)
            _actionTile(
              context: context,
              icon: Icons.mail_outlined,
              label: l.vetFieldEmail,
              value: vet.email!,
              onTap: () => _sendMail(context, vet.email!),
              onLongPress: () => _copy(context, vet.email!, l),
            ),
          if (vet.address != null && vet.address!.isNotEmpty)
            _actionTile(
              context: context,
              icon: Icons.map_outlined,
              label: l.vetFieldAddress,
              value: vet.address!,
              onTap: () => _openMap(context, vet.address!),
              onLongPress: () => _copy(context, vet.address!, l),
            ),
          if (vet.notes != null && vet.notes!.isNotEmpty)
            _readOnlyTile(
              context: context,
              icon: Icons.notes_outlined,
              label: l.petFieldNotes,
              value: vet.notes!,
            ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _readOnlyTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.outline),
      title: Text(label),
      subtitle: Text(value),
    );
  }

  Future<void> _callNumber(BuildContext context, String raw) async {
    final uri = Uri(scheme: 'tel', path: _stripPhone(raw));
    await _launch(context, uri);
  }

  Future<void> _sendMail(BuildContext context, String raw) async {
    final uri = Uri(scheme: 'mailto', path: raw.trim());
    await _launch(context, uri);
  }

  Future<void> _openMap(BuildContext context, String raw) async {
    final encoded = Uri.encodeComponent(raw.trim());
    // geo:0,0?q= is Android's canonical maps intent, handled by any
    // installed maps app (Google Maps, OSMAnd, etc.).
    final uri = Uri.parse('geo:0,0?q=$encoded');
    await _launch(context, uri);
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final l = AppL10n.of(context);
    try {
      final ok = await launchUrl(uri);
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

  Future<void> _copy(BuildContext context, String text, AppL10n l) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.copiedToClipboard)),
      );
    }
  }

  String _stripPhone(String raw) {
    // Keep leading + and digits — drop spaces / dashes / parens.
    return raw.replaceAll(RegExp(r'[^\d+]'), '');
  }
}
