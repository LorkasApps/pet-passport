import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores paths in the DB as **relative** to the app documents dir.
/// Resolves them to absolute paths at read time.
class MediaService {
  MediaService({Future<Directory> Function()? docDirLoader})
      : _docDirLoader = docDirLoader ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _docDirLoader;
  Directory? _mediaRoot;

  Future<Directory> _root() async {
    final cached = _mediaRoot;
    if (cached != null) return cached;
    final docs = await _docDirLoader();
    final root = Directory(p.join(docs.path, 'media'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _mediaRoot = root;
    return root;
  }

  Future<String> resolve(String relativePath) async {
    final root = await _root();
    return p.join(root.path, relativePath);
  }

  /// Copies [source] into `<media>/pets/<petUuid>/profile<ext>` and returns
  /// the relative path suitable for storage in the DB.
  Future<String> savePetProfilePhoto({
    required String petUuid,
    required File source,
  }) async {
    final root = await _root();
    final ext = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    final relative = p.join('pets', petUuid, 'profile$ext');
    final target = File(p.join(root.path, relative));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return relative;
  }

  Future<void> deleteFile(String relativePath) async {
    final absolute = await resolve(relativePath);
    final file = File(absolute);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Media deletion is best-effort — DB is source of truth.
      }
    }
  }

  /// Copies [source] to `<media>/insurances/<insuranceUuid>/<docUuid><ext>`
  /// and returns the relative path.
  Future<String> saveInsuranceDocument({
    required String insuranceUuid,
    required String docUuid,
    required File source,
  }) async {
    return _copyDocument(
      source: source,
      relativeDir: p.join('insurances', insuranceUuid),
      docUuid: docUuid,
    );
  }

  /// Copies [source] to `<media>/vaccinations/<vaccinationUuid>/<docUuid><ext>`
  /// and returns the relative path.
  Future<String> saveVaccinationDocument({
    required String vaccinationUuid,
    required String docUuid,
    required File source,
  }) async {
    return _copyDocument(
      source: source,
      relativeDir: p.join('vaccinations', vaccinationUuid),
      docUuid: docUuid,
    );
  }

  /// Copies [source] to `<media>/events/<eventUuid>/<photoUuid><ext>` and
  /// returns the relative path.
  Future<String> saveEventPhoto({
    required String eventUuid,
    required String photoUuid,
    required File source,
  }) async {
    return _copyDocument(
      source: source,
      relativeDir: p.join('events', eventUuid),
      docUuid: photoUuid,
    );
  }

  Future<String> _copyDocument({
    required File source,
    required String relativeDir,
    required String docUuid,
  }) async {
    final root = await _root();
    final ext = p.extension(source.path).isEmpty
        ? ''
        : p.extension(source.path);
    final relative = p.join(relativeDir, '$docUuid$ext');
    final target = File(p.join(root.path, relative));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return relative;
  }
}
