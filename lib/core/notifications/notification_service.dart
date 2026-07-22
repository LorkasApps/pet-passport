import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_ids.dart';

typedef NotificationTapHandler = void Function(NotificationPayload payload);

class NotificationPayload {
  const NotificationPayload({
    required this.entity,
    required this.uuid,
  });

  final String entity; // e.g. "vaccination"
  final String uuid;

  Map<String, dynamic> toJson() => {'entity': entity, 'uuid': uuid};

  static NotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPayload(
        entity: map['entity'] as String,
        uuid: map['uuid'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  NotificationTapHandler? _onTap;
  bool _initialized = false;

  /// Timezone database + platform plugin init. Idempotent.
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Best-effort: use device's local timezone via platform default.
    tz.setLocalLocation(tz.getLocation(tz.local.name));

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleResponse,
    );
    _initialized = true;
  }

  void setTapHandler(NotificationTapHandler handler) {
    _onTap = handler;
  }

  Future<bool> requestPermissions() async {
    final notif = await Permission.notification.request();
    // Exact alarms permission — best-effort. Fallback path: inexact alarm.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      try {
        await androidImpl.requestExactAlarmsPermission();
      } catch (_) {}
    }
    return notif.isGranted;
  }

  Future<bool> canScheduleExactAlarms() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return false;
    try {
      return await androidImpl.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleVaccinationReminder({
    required String uuid,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    final id = NotificationIds.forVaccination(uuid);
    // Cancel first for idempotent re-schedule after edits.
    await _plugin.cancel(id);
    if (whenLocal.isBefore(DateTime.now())) return;
    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vaccinations',
        'Vaccinations',
        channelDescription: 'Reminders for upcoming and due vaccinations.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final exact = await canScheduleExactAlarms();
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode(
          const NotificationPayload(entity: 'vaccination', uuid: '').toJson()
            ..['uuid'] = uuid,
        ),
      );
    } catch (e, st) {
      // Never let a scheduling failure crash a save. Log for diagnostics.
      if (kDebugMode) {
        debugPrint('scheduleVaccinationReminder failed: $e\n$st');
      }
    }
  }

  Future<void> cancelVaccinationReminder(String uuid) async {
    await _plugin.cancel(NotificationIds.forVaccination(uuid));
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = NotificationPayload.tryParse(response.payload);
    if (payload != null) _onTap?.call(payload);
  }
}
