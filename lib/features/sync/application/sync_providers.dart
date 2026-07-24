import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../data/sync_outbox.dart';

final syncOutboxProvider = Provider<SyncOutbox>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncOutbox(db);
});
