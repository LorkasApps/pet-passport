import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'storage_api.dart';

/// Supabase-backed [StorageApi]. Every method funnels through the
/// same exception classifier the SupabaseCloudApi uses for row
/// pushes: PostgREST-style HTTP codes → retryable/terminal.
class SupabaseStorageApi implements StorageApi {
  SupabaseStorageApi({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<StorageResult> uploadObject({
    required String bucket,
    required String key,
    required File file,
    String? mimeType,
  }) async {
    try {
      await _client.storage.from(bucket).upload(
            key,
            file,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );
      return const StorageOk();
    } on StorageException catch (e) {
      return _classifyUpload(e);
    } on SocketException catch (e) {
      return StorageRetryable('socket: ${e.message}');
    } on TimeoutException catch (_) {
      return const StorageRetryable('timeout');
    } catch (e) {
      return StorageRetryable('unknown: $e');
    }
  }

  @override
  Future<StorageResult> deleteObject({
    required String bucket,
    required String key,
  }) async {
    try {
      await _client.storage.from(bucket).remove([key]);
      return const StorageOk();
    } on StorageException catch (e) {
      // A missing object on delete is idempotent success — the caller
      // wanted the object gone and it is.
      if ((e.statusCode ?? '') == '404' ||
          (e.error ?? '').toLowerCase().contains('not found')) {
        return const StorageOk();
      }
      return _classifyUpload(e);
    } on SocketException catch (e) {
      return StorageRetryable('socket: ${e.message}');
    } on TimeoutException catch (_) {
      return const StorageRetryable('timeout');
    } catch (e) {
      return StorageRetryable('unknown: $e');
    }
  }

  @override
  Future<StorageDownloadResult> downloadObject({
    required String bucket,
    required String key,
  }) async {
    try {
      final bytes = await _client.storage.from(bucket).download(key);
      return StorageDownloadOk(bytes);
    } on StorageException catch (e) {
      final http = int.tryParse(e.statusCode ?? '') ?? 500;
      if (http == 404) return StorageDownloadTerminal('http 404: ${e.message}');
      if (http == 429 || (http >= 500 && http < 600)) {
        return StorageDownloadRetryable('http $http: ${e.message}');
      }
      return StorageDownloadTerminal('http $http: ${e.message}');
    } on SocketException catch (e) {
      return StorageDownloadRetryable('socket: ${e.message}');
    } on TimeoutException catch (_) {
      return const StorageDownloadRetryable('timeout');
    } catch (e) {
      return StorageDownloadRetryable('unknown: $e');
    }
  }

  StorageResult _classifyUpload(StorageException e) {
    final http = int.tryParse(e.statusCode ?? '') ?? 500;
    if (http == 429 || (http >= 500 && http < 600)) {
      return StorageRetryable('http $http: ${e.message}');
    }
    if (http == 401) return StorageRetryable('http 401: ${e.message}');
    // 400 / 403 / 409 / 422: content, quota, mime, RLS. Retrying
    // won't help without user intervention.
    return StorageTerminal('http $http: ${e.message}');
  }
}
