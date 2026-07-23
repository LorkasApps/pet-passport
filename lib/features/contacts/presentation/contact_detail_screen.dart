import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/util/maps_launcher.dart';
import '../application/contacts_providers.dart';
import '../domain/contact.dart';
import 'contacts_list_screen.dart' show contactRoleLabel;

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({
    super.key,
    required this.petUuid,
    required this.contactUuid,
  });

  final String petUuid;
  final String contactUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      contactByUuidProvider((contactUuid: contactUuid, petUuid: petUuid)),
    );
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (contact) {
        if (contact == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('—')),
          );
        }
        return _ContactDetailContent(contact: contact, petUuid: petUuid);
      },
    );
  }
}

class _ContactDetailContent extends StatelessWidget {
  const _ContactDetailContent({required this.contact, required this.petUuid});

  final Contact contact;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l.actionEdit,
            onPressed: () => context
                .push('/pets/$petUuid/contacts/${contact.uuid}/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _readOnlyTile(
            context: context,
            icon: Icons.badge_outlined,
            label: l.contactFieldRole,
            value: contactRoleLabel(l, contact.role),
          ),
          if (contact.organization != null && contact.organization!.isNotEmpty)
            _readOnlyTile(
              context: context,
              icon: Icons.business_outlined,
              label: l.contactFieldOrganization,
              value: contact.organization!,
            ),
          if (contact.phone != null && contact.phone!.isNotEmpty)
            _actionTile(
              context: context,
              icon: Icons.phone_outlined,
              label: l.contactFieldPhone,
              value: contact.phone!,
              onTap: () => _callNumber(context, contact.phone!),
              onLongPress: () => _copy(context, contact.phone!, l),
            ),
          if (contact.email != null && contact.email!.isNotEmpty)
            _actionTile(
              context: context,
              icon: Icons.mail_outlined,
              label: l.contactFieldEmail,
              value: contact.email!,
              onTap: () => _sendMail(context, contact.email!),
              onLongPress: () => _copy(context, contact.email!, l),
            ),
          if (contact.address != null && contact.address!.isNotEmpty)
            _actionTile(
              context: context,
              icon: Icons.map_outlined,
              label: l.contactFieldAddress,
              value: contact.address!,
              onTap: () => openInMaps(context, contact.address!),
              onLongPress: () => _copy(context, contact.address!, l),
            ),
          if (contact.notes != null && contact.notes!.isNotEmpty)
            _readOnlyTile(
              context: context,
              icon: Icons.notes_outlined,
              label: l.petFieldNotes,
              value: contact.notes!,
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

  String _stripPhone(String raw) => raw.replaceAll(RegExp(r'[^\d+]'), '');
}
