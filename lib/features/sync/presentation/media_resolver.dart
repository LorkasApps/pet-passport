import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../pets/application/pets_providers.dart' show mediaServiceProvider;
import '../application/sync_providers.dart';

/// Resolves a media artefact to an absolute local file path, using
/// whichever route is available:
///   1. Local file at [relativePath] (this device wrote it, or the
///      MediaFetcher previously cached it here).
///   2. Cache-dir hit for [storageKey].
///   3. Cloud download via [MediaFetcher.resolve].
///
/// Returns `null` on all-around failure — callers show a placeholder.
Future<String?> resolveMediaPath(
  WidgetRef ref, {
  String? relativePath,
  String? storageKey,
}) async {
  final media = ref.read(mediaServiceProvider);
  String? localHintAbsolute;
  if (relativePath != null && relativePath.isNotEmpty) {
    localHintAbsolute = await media.resolve(relativePath);
    if (await File(localHintAbsolute).exists()) return localHintAbsolute;
  }
  final fetcher = ref.read(mediaFetcherProvider);
  if (fetcher == null) return null;
  return fetcher.resolve(
    storageKey: storageKey,
    localHintAbsolute: localHintAbsolute,
  );
}

/// Wraps [resolveMediaPath] + [OpenFilex] with a friendly snack-bar
/// fallback. Every doc/photo tap in the app funnels through this.
Future<void> openMedia(
  BuildContext context,
  WidgetRef ref, {
  String? relativePath,
  String? storageKey,
}) async {
  final l = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final absolute = await resolveMediaPath(
    ref,
    relativePath: relativePath,
    storageKey: storageKey,
  );
  if (absolute == null) {
    messenger.showSnackBar(SnackBar(content: Text(l.mediaUnavailable)));
    return;
  }
  final result = await OpenFilex.open(absolute);
  if (result.type != ResultType.done && context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l.launchFailed)));
  }
}

/// Image widget that resolves lazily via [resolveMediaPath] and shows
/// a spinner while the fetcher is working. Replaces bare
/// `Image.file(File(path))` at every render site so cross-device
/// downloads land as soon as the row arrives.
///
/// `builder` lets the caller decide how the resolved file is
/// rendered — CircleAvatar / Image.file / etc. — while this widget
/// still owns the resolve+placeholder dance.
class MediaAsset extends ConsumerWidget {
  const MediaAsset({
    super.key,
    required this.relativePath,
    required this.storageKey,
    required this.builder,
    this.placeholder,
  });

  /// Device-local path hint (relative to the media root). May be
  /// null / empty when we've never had the file locally.
  final String? relativePath;

  /// Cloud storage key — filled once the media outbox has uploaded.
  /// Null while the row is still local-only.
  final String? storageKey;

  /// Renderer, invoked once we have a real file on disk.
  final Widget Function(BuildContext context, File file) builder;

  /// Shown while the file is being resolved / downloaded, and as
  /// the fallback when neither the local hint nor the cloud copy
  /// can produce a file.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: resolveMediaPath(
        ref,
        relativePath: relativePath,
        storageKey: storageKey,
      ),
      builder: (context, snap) {
        final path = snap.data;
        if (snap.connectionState != ConnectionState.done || path == null) {
          return placeholder ?? const SizedBox.shrink();
        }
        return builder(context, File(path));
      },
    );
  }
}
