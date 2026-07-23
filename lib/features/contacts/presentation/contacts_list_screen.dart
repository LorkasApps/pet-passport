import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/contacts_providers.dart';
import '../domain/contact.dart';
import '../domain/contact_enums.dart';

class ContactsListScreen extends ConsumerStatefulWidget {
  const ContactsListScreen({super.key});

  @override
  ConsumerState<ContactsListScreen> createState() =>
      _ContactsListScreenState();
}

class _ContactsListScreenState extends ConsumerState<ContactsListScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.contactsListTitle),
        actions: [
          IconButton(
            icon: Icon(_showArchived
                ? Icons.visibility_off_outlined
                : Icons.archive_outlined),
            tooltip: _showArchived
                ? l.actionHideArchived
                : l.actionShowArchived,
            onPressed: () =>
                setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pet) {
          if (pet == null) {
            return EmptyState(
              icon: Icons.pets_outlined,
              title: l.petsListEmpty,
            );
          }
          final async = ref.watch(contactsForPetProvider(pet.uuid));
          return async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (contacts) {
              final active = contacts.where((c) => c.isActive).toList();
              final archived = contacts.where((c) => !c.isActive).toList();
              if (active.isEmpty && (!_showArchived || archived.isEmpty)) {
                return EmptyState(
                  icon: Icons.contact_page_outlined,
                  title: l.contactsEmptyTitle,
                  message: l.contactsEmptyMessage,
                  actionLabel: l.contactsEmptyAction,
                  onAction: () =>
                      context.push('/pets/${pet.uuid}/contacts/new'),
                  secondaryActionLabel: archived.isEmpty
                      ? null
                      : l.emptyShowArchivedAction(archived.length),
                  onSecondaryAction: archived.isEmpty
                      ? null
                      : () => setState(() => _showArchived = true),
                );
              }
              return ListView(
                children: [
                  for (final c in active)
                    _ContactTile(contact: c, petUuid: pet.uuid),
                  if (_showArchived && archived.isNotEmpty) ...[
                    _SectionHeader(text: l.vetsArchivedSection),
                    for (final c in archived)
                      _ContactTile(contact: c, petUuid: pet.uuid),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: petAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'contacts-fab',
              onPressed: () =>
                  context.push('/pets/${petAsync.value!.uuid}/contacts/new'),
              icon: const Icon(Icons.add),
              label: Text(l.actionAdd),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.petUuid});
  final Contact contact;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(_iconFor(contact.role)),
      ),
      title: Text(contact.name),
      subtitle: Text(_subtitleFor(l, contact)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          context.push('/pets/$petUuid/contacts/${contact.uuid}'),
    );
  }

  IconData _iconFor(ContactRole role) => switch (role) {
        ContactRole.sitter => Icons.pets_outlined,
        ContactRole.trainer => Icons.school_outlined,
        ContactRole.groomer => Icons.brush_outlined,
        ContactRole.other => Icons.person_outline,
      };

  String _subtitleFor(AppL10n l, Contact c) {
    final role = contactRoleLabel(l, c.role);
    if (c.organization != null && c.organization!.isNotEmpty) {
      return '$role · ${c.organization}';
    }
    return role;
  }
}

String contactRoleLabel(AppL10n l, ContactRole role) => switch (role) {
      ContactRole.sitter => l.contactRoleSitter,
      ContactRole.trainer => l.contactRoleTrainer,
      ContactRole.groomer => l.contactRoleGroomer,
      ContactRole.other => l.contactRoleOther,
    };
