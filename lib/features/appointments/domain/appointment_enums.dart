/// Type discriminator for `appointments.type`. Drift stores the enum index,
/// so appending is safe; reordering breaks stored rows.
enum AppointmentType { vet, grooming, training, walk, checkup, other }

/// Recurrence frequency for `appointments.recurrence_freq`. Index-stored.
enum RecurrenceFreq { none, daily, weekly, monthly }
