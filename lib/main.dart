import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/notification_service.dart';
import 'features/settings/application/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init notification stack before runApp so scheduled callbacks can fire
  // even when the app is launched from a notification tap.
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const PetPassportApp(),
    ),
  );
}
