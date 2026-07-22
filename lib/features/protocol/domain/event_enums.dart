/// Event type discriminator. Order is load-bearing — Drift stores the enum
/// index in `events.event_type`, so appending new values at the end is
/// safe; reordering existing values is not.
enum EventType { weight, feeding, symptom, activity, generic }

enum FeedingMeal { morning, noon, evening, snack }

enum SymptomSeverity { low, medium, high }

enum ActivityType { walk, play, training, other }
