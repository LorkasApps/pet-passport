import 'package:drift/drift.dart';

import 'event_tags_table.dart';
import 'events_table.dart';

@DataClassName('EventTagLinkRow')
class EventTagLinks extends Table {
  IntColumn get eventId =>
      integer().references(Events, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(EventTags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {eventId, tagId};
}
