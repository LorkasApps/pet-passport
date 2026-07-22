import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../application/current_pet_provider.dart';
import '../application/pets_providers.dart';
import '../domain/pet.dart';
import '../domain/pet_enums.dart';

class PetEditScreen extends ConsumerStatefulWidget {
  const PetEditScreen({super.key, this.petUuid});

  final String? petUuid;

  bool get isEdit => petUuid != null;

  @override
  ConsumerState<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends ConsumerState<PetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _chipCtrl = TextEditingController();
  final _tassoCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  List<String> _allergies = const [];

  Species _species = Species.dog;
  Sex _sex = Sex.male;
  bool _isNeutered = false;
  DateTime? _dob;
  String? _photoPathTemp; // absolute path of new pick, until save
  String? _photoPathStored; // relative path stored in DB
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _colorCtrl.dispose();
    _chipCtrl.dispose();
    _tassoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(Pet pet) {
    if (_prefilled) return;
    _prefilled = true;
    _nameCtrl.text = pet.name;
    _breedCtrl.text = pet.breed ?? '';
    _colorCtrl.text = pet.color ?? '';
    _chipCtrl.text = pet.chipNumber ?? '';
    _tassoCtrl.text = pet.tassoNumber ?? '';
    _allergies = _splitAllergies(pet.allergies);
    _notesCtrl.text = pet.notes ?? '';
    _species = pet.species;
    _sex = pet.sex;
    _isNeutered = pet.isNeutered;
    _dob = pet.dateOfBirth;
    _photoPathStored = pet.profilePhotoPath;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() => _photoPathTemp = picked.path);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 2, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 40),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(petsRepositoryProvider);
      final media = ref.read(mediaServiceProvider);

      final name = _nameCtrl.text.trim();
      final breed = _emptyToNull(_breedCtrl.text);
      final color = _emptyToNull(_colorCtrl.text);
      final chip = _emptyToNull(_chipCtrl.text);
      final tasso = _emptyToNull(_tassoCtrl.text);
      final allergies = _allergies.isEmpty ? null : _allergies.join(', ');
      final notes = _emptyToNull(_notesCtrl.text);

      String uuid;
      if (widget.isEdit) {
        uuid = widget.petUuid!;
        var photoRel = _photoPathStored;
        if (_photoPathTemp != null) {
          photoRel = await media.savePetProfilePhoto(
            petUuid: uuid,
            source: File(_photoPathTemp!),
          );
        }
        await repo.updatePet(
          uuid: uuid,
          name: name,
          species: _species,
          sex: _sex,
          isNeutered: _isNeutered,
          breed: breed,
          dateOfBirth: _dob,
          color: color,
          chipNumber: chip,
          tassoNumber: tasso,
          profilePhotoPath: photoRel,
          allergies: allergies,
          notes: notes,
        );
      } else {
        uuid = await repo.createPet(
          name: name,
          species: _species,
          sex: _sex,
          isNeutered: _isNeutered,
          breed: breed,
          dateOfBirth: _dob,
          color: color,
          chipNumber: chip,
          tassoNumber: tasso,
          allergies: allergies,
          notes: notes,
        );
        // First-ever pet becomes the active profile automatically.
        await setCurrentPet(ref, uuid);
        if (_photoPathTemp != null) {
          final rel = await media.savePetProfilePhoto(
            petUuid: uuid,
            source: File(_photoPathTemp!),
          );
          await repo.updatePet(
            uuid: uuid,
            name: name,
            species: _species,
            sex: _sex,
            breed: breed,
            dateOfBirth: _dob,
            color: color,
            chipNumber: chip,
            tassoNumber: tasso,
            profilePhotoPath: rel,
            notes: notes,
          );
        }
      }

      if (!mounted) return;
      if (widget.isEdit) {
        context.pop();
      } else {
        context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _splitAllergies(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _addAllergy() async {
    final l = AppL10n.of(context);
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.petAllergyAddTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l.petAllergyHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(l.actionAdd),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    if (_allergies.contains(value)) return;
    setState(() => _allergies = [..._allergies, value]);
  }

  Future<void> _confirmDelete(BuildContext context, AppL10n l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.confirmDeleteTitle),
        content: Text(l.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(petsRepositoryProvider).softDelete(widget.petUuid!);
    if (!context.mounted) return;
    // currentPetProvider self-heals to next active pet (or null).
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final title = widget.isEdit ? l.petEditEditTitle : l.petEditNewTitle;

    if (widget.isEdit) {
      final async = ref.watch(petByUuidProvider(widget.petUuid!));
      return async.when(
        loading: () => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text('$e')),
        ),
        data: (pet) {
          if (pet == null) {
            return Scaffold(appBar: AppBar(title: Text(title)));
          }
          _prefill(pet);
          return _buildScaffold(context, title, l);
        },
      );
    }
    return _buildScaffold(context, title, l);
  }

  Widget _buildScaffold(BuildContext context, String title, AppL10n l) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l.actionDelete,
              onPressed: _saving ? null : () => _confirmDelete(context, l),
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l.actionSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: _photoField(context, l)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l.petFieldName),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.validationRequired
                  : (v.trim().length > 100 ? l.validationTooLong : null),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Species>(
              initialValue: _species,
              decoration: InputDecoration(labelText: l.petFieldSpecies),
              items: [
                DropdownMenuItem(
                    value: Species.dog, child: Text(l.speciesDog)),
                DropdownMenuItem(
                    value: Species.cat, child: Text(l.speciesCat)),
              ],
              onChanged: (v) =>
                  setState(() => _species = v ?? Species.dog),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Sex>(
              initialValue: _sex,
              decoration: InputDecoration(labelText: l.petFieldSex),
              items: [
                DropdownMenuItem(value: Sex.male, child: Text(l.sexMale)),
                DropdownMenuItem(
                    value: Sex.female, child: Text(l.sexFemale)),
              ],
              onChanged: (v) => setState(() => _sex = v ?? Sex.male),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isNeutered,
              onChanged: (v) => setState(() => _isNeutered = v),
              title: Text(l.petFieldNeutered),
              subtitle: Text(l.petFieldNeuteredHelp),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _breedCtrl,
              decoration: InputDecoration(labelText: l.petFieldBreed),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDob,
              child: InputDecorator(
                decoration:
                    InputDecoration(labelText: l.petFieldDateOfBirth),
                child: Text(
                  _dob == null
                      ? '—'
                      : DateFormat.yMd(
                              Localizations.localeOf(context).toString())
                          .format(_dob!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _colorCtrl,
              decoration: InputDecoration(labelText: l.petFieldColor),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _chipCtrl,
              decoration: InputDecoration(labelText: l.petFieldChipNumber),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tassoCtrl,
              decoration:
                  InputDecoration(labelText: l.petFieldTassoNumber),
            ),
            const SizedBox(height: 16),
            Text(l.petFieldAllergies,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(l.petFieldAllergiesHelp,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in _allergies)
                  InputChip(
                    label: Text(a),
                    onDeleted: () => setState(
                        () => _allergies = List.of(_allergies)..remove(a)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l.petAllergyAddAction),
                  onPressed: _addAllergy,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l.petFieldNotes),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoField(BuildContext context, AppL10n l) {
    final scheme = Theme.of(context).colorScheme;
    final tempPath = _photoPathTemp;
    ImageProvider? image;
    if (tempPath != null) {
      image = FileImage(File(tempPath));
    } else if (_photoPathStored != null) {
      // Resolved lazily via FutureBuilder to keep this widget simple.
      return FutureBuilder<String>(
        future: ref
            .read(mediaServiceProvider)
            .resolve(_photoPathStored!),
        builder: (context, snap) {
          final resolved = snap.data;
          final img = resolved != null ? FileImage(File(resolved)) : null;
          return _avatarStack(scheme, img, l);
        },
      );
    }
    return _avatarStack(scheme, image, l);
  }

  Widget _avatarStack(
      ColorScheme scheme, ImageProvider? image, AppL10n l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: scheme.secondaryContainer,
          backgroundImage: image,
          child: image == null
              ? Icon(Icons.pets, size: 48, color: scheme.onSecondaryContainer)
              : null,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(image == null
              ? l.petPickProfilePhoto
              : l.petReplaceProfilePhoto),
        ),
      ],
    );
  }
}
