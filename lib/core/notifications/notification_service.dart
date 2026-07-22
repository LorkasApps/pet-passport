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
    this.extra = const {},
  });

  final String entity; // e.g. "vaccination", "appointment", "medication"
  final String uuid;
  final Map<String, String> extra;

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'uuid': uuid,
        if (extra.isNotEmpty) 'extra': extra,
      };

  static NotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final extraRaw = map['extra'];
      final extra = <String, String>{};
      if (extraRaw is Map) {
        for (final entry in extraRaw.entries) {
          extra[entry.key.toString()] = entry.value.toString();
        }
      }
      return NotificationPayload(
        entity: map['entity'] as String,
        uuid: map['uuid'] as String,
        extra: extra,
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

  /// Tracks scheduled IDs per (entity, uuid) so we can cancel every slot
  /// (e.g. all occurrences of a recurring appointment) without knowing them
  /// individually. Persistence not needed — call sites re-add on every
  /// scheduleReminder + a boot-time reschedule rebuilds after cold start.
  final Map<String, Set<int>> _idsByEntity = {};

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

  /// If the app was cold-launched via a notification tap, returns the payload
  /// so the router can deep-link before the first frame.
  Future<NotificationPayload?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return NotificationPayload.tryParse(
      details.notificationResponse?.payload,
    );
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

  /// Schedule (or reschedule) one reminder slot. IDs are deterministic so
  /// calling this multiple times with the same (entity, uuid, slot) is safe.
  ///
  /// - `channelId`/`channelName` govern Android notification channels; use
  ///   the same values for all reminders in a category so the user's
  ///   channel preferences apply consistently.
  /// - `slot` should be built via [NotificationIds.slotFor] for recurring
  ///   reminders. For single-shot reminders, pass an empty string.
  Future<void> scheduleReminder({
    required String entity,
    required String uuid,
    required String slot,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    required DateTime whenLocal,
    Map<String, String> extra = const {},
  }) async {
    final id = NotificationIds.forSlot(
      entity: entity, uuid: uuid, slot: slot,
    );
    await _plugin.cancel(id);
    _rememberId(entity, uuid, id);
    if (!whenLocal.isAfter(DateTime.now())) return;
    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
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
          NotificationPayload(entity: entity, uuid: uuid, extra: extra)
              .toJson(),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('scheduleReminder failed ($entity:$uuid:$slot): $e\n$st');
      }
    }
  }

  /// Cancel a single scheduled slot. No-op if the slot was never scheduled.
  Future<void> cancelReminder({
    required String entity,
    required String uuid,
    required String slot,
  }) async {
    final id = NotificationIds.forSlot(
      entity: entity, uuid: uuid, slot: slot,
    );
    await _plugin.cancel(id);
    _forgetId(entity, uuid, id);
  }

  /// Cancel every slot ever tracked for (entity, uuid) via this instance.
  /// Useful when deleting the parent entity (appointment, medication, …).
  Future<void> cancelAllForEntity({
    required String entity,
    required String uuid,
  }) async {
    final ids = _idsByEntity.remove(_entityKey(entity, uuid));
    if (ids == null) return;
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  // --- backwards-compat shims — new code should use scheduleReminder. ---

  Future<void> scheduleVaccinationReminder({
    required String uuid,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) {
    return scheduleReminder(
      entity: 'vac',
      uuid: uuid,
      slot: '',
      channelId: 'vaccinations',
      channelName: 'Vaccinations',
      channelDescription: 'Reminders for upcoming and due vaccinations.',
      title: title,
      body: body,
      whenLocal: whenLocal,
    );
  }

  Future<void> cancelVaccinationReminder(String uuid) {
    return cancelReminder(entity: 'vac', uuid: uuid, slot: '');
  }

  // --- internals ---

  String _entityKey(String entity, String uuid) => '$entity:$uuid';

  void _rememberId(String entity, String uuid, int id) {
    _idsByEntity.putIfAbsent(_entityKey(entity, uuid), () => <int>{}).add(id);
  }

  void _forgetId(String entity, String uuid, int id) {
    final key = _entityKey(entity, uuid);
    final set = _idsByEntity[key];
    if (set == null) return;
    set.remove(id);
    if (set.isEmpty) _idsByEntity.remove(key);
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = NotificationPayload.tryParse(response.payload);
    if (payload != null) _onTap?.call(payload);
  }
}
