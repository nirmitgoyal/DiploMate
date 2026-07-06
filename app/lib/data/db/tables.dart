// Drift mirror of the Postgres content shape (sql/0001_content_v0.sql) plus
// local-first event/bookmark/cache tables. Column names mirror the SQL DDL
// exactly (drift emits snake_case from these camelCase getters).
// Wire enums (rating, event_type) are OWNED by sql/ DDL:
//   rating     -> sql/0003_users_events.sql  review_events_rating_check
//   event_type -> sql/0003_users_events.sql  app_events_event_type_check
import 'package:drift/drift.dart';

class Specialities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get examType => text()();
  TextColumn get slug => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get specialityId => text()();
  TextColumn get title => text()();
  TextColumn get slug => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get examWeight => integer().withDefault(const Constant(0))();
  IntColumn get contentVersion => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Topics extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text()();
  TextColumn get title => text()();
  TextColumn get slug => text()();
  TextColumn get examTheme => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Qnas extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get question => text()();
  TextColumn get years => text().nullable()();
  IntColumn get marks => integer().nullable()();
  TextColumn get earnsMarks => text()(); // JSON string, same shape as Postgres JSONB
  TextColumn get sections => text()(); // JSON string, same shape as Postgres JSONB
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

// Image METADATA only - bytes live in ImageBlobs (fetched lazily, cached).
class Images extends Table {
  TextColumn get id => text()();
  TextColumn get qnaId => text()();
  TextColumn get caption => text()();
  TextColumn get contentDescription => text()();
  IntColumn get byteSize => integer()();
  TextColumn get sha256 => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class ImageBlobs extends Table {
  TextColumn get imageId => text()();
  BlobColumn get bytes => blob()();
  TextColumn get sha256 => text()();
  @override
  Set<Column> get primaryKey => {imageId};
}

// Full local review-event log. "Pending" = synced_at IS NULL; plan 6 sync
// sets synced_at after a 200, never deletes (the Leitner fold needs history).
class PendingReviewEvents extends Table {
  TextColumn get id => text()(); // client-generated UUID (D4 idempotency key)
  TextColumn get contentId => text()(); // QnA ULID (D14)
  TextColumn get rating => text()(); // wire enum, owned by sql/ DDL
  DateTimeColumn get shownAt => dateTime()();
  DateTimeColumn get revealedAt => dateTime()();
  DateTimeColumn get ratedAt => dateTime()();
  TextColumn get localDay => text()(); // "YYYY-MM-DD", 4am rollover
  DateTimeColumn get syncedAt => dateTime().nullable()();
  IntColumn get syncAttempts => integer().withDefault(const Constant(0))(); // poison drop after 5 (T4)
  @override
  Set<Column> get primaryKey => {id};
}

class PendingAppEvents extends Table {
  TextColumn get id => text()(); // client-generated UUID
  TextColumn get eventType => text()(); // wire enum, owned by sql/ DDL
  TextColumn get contentId => text().nullable()();
  IntColumn get hiddenMs => integer().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get localDay => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  IntColumn get syncAttempts => integer().withDefault(const Constant(0))(); // poison drop after 5 (T4)
  @override
  Set<Column> get primaryKey => {id};
}

// Local LWW copy; user scoping is server-side (one signed-in user per device DB).
class Bookmarks extends Table {
  TextColumn get contentId => text()();
  DateTimeColumn get updatedAt => dateTime()(); // LWW key
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {contentId};
}

class CachedChapters extends Table {
  TextColumn get chapterId => text()();
  IntColumn get contentVersion => integer()();
  DateTimeColumn get cachedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {chapterId};
}

// Client-only flags (never synced). Today: 'reminder_enabled' = 'true'|'false'.
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}
