import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment.dart';

// Re-export UpcomingAppointment so consumers don't have to reach into data/.
export '../data/appointments_repository.dart' show UpcomingAppointment;

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  final outbox = ref.watch(syncOutboxProvider);
  return AppointmentsRepository(
    db.appointmentsDao,
    db.petsDao,
    db.vetsDao,
    db.contactsDao,
    notifications: notif,
    outbox: outbox,
  );
});

final appointmentsForPetProvider =
    StreamProvider.family<List<Appointment>, String>((ref, petUuid) {
  return ref.watch(appointmentsRepositoryProvider).watchForPetUuid(petUuid);
});

final upcomingAppointmentsForPetProvider =
    StreamProvider.family<List<UpcomingAppointment>, String>((ref, petUuid) {
  return ref
      .watch(appointmentsRepositoryProvider)
      .watchUpcomingForPetUuid(petUuid);
});

final appointmentByUuidProvider = StreamProvider.family<
    Appointment?, ({String apptUuid, String petUuid})>((ref, args) {
  return ref
      .watch(appointmentsRepositoryProvider)
      .watchByUuid(args.apptUuid, args.petUuid);
});
