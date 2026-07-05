// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $SpecialitiesTable extends Specialities
    with TableInfo<$SpecialitiesTable, Speciality> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpecialitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _examTypeMeta =
      const VerificationMeta('examType');
  @override
  late final GeneratedColumn<String> examType = GeneratedColumn<String>(
      'exam_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, name, examType, slug, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'specialities';
  @override
  VerificationContext validateIntegrity(Insertable<Speciality> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('exam_type')) {
      context.handle(_examTypeMeta,
          examType.isAcceptableOrUnknown(data['exam_type']!, _examTypeMeta));
    } else if (isInserting) {
      context.missing(_examTypeMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Speciality map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Speciality(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      examType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exam_type'])!,
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $SpecialitiesTable createAlias(String alias) {
    return $SpecialitiesTable(attachedDatabase, alias);
  }
}

class Speciality extends DataClass implements Insertable<Speciality> {
  final String id;
  final String name;
  final String examType;
  final String slug;
  final int sortOrder;
  const Speciality(
      {required this.id,
      required this.name,
      required this.examType,
      required this.slug,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['exam_type'] = Variable<String>(examType);
    map['slug'] = Variable<String>(slug);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SpecialitiesCompanion toCompanion(bool nullToAbsent) {
    return SpecialitiesCompanion(
      id: Value(id),
      name: Value(name),
      examType: Value(examType),
      slug: Value(slug),
      sortOrder: Value(sortOrder),
    );
  }

  factory Speciality.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Speciality(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      examType: serializer.fromJson<String>(json['examType']),
      slug: serializer.fromJson<String>(json['slug']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'examType': serializer.toJson<String>(examType),
      'slug': serializer.toJson<String>(slug),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Speciality copyWith(
          {String? id,
          String? name,
          String? examType,
          String? slug,
          int? sortOrder}) =>
      Speciality(
        id: id ?? this.id,
        name: name ?? this.name,
        examType: examType ?? this.examType,
        slug: slug ?? this.slug,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  Speciality copyWithCompanion(SpecialitiesCompanion data) {
    return Speciality(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      examType: data.examType.present ? data.examType.value : this.examType,
      slug: data.slug.present ? data.slug.value : this.slug,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Speciality(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('examType: $examType, ')
          ..write('slug: $slug, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, examType, slug, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Speciality &&
          other.id == this.id &&
          other.name == this.name &&
          other.examType == this.examType &&
          other.slug == this.slug &&
          other.sortOrder == this.sortOrder);
}

class SpecialitiesCompanion extends UpdateCompanion<Speciality> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> examType;
  final Value<String> slug;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const SpecialitiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.examType = const Value.absent(),
    this.slug = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpecialitiesCompanion.insert({
    required String id,
    required String name,
    required String examType,
    required String slug,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        examType = Value(examType),
        slug = Value(slug);
  static Insertable<Speciality> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? examType,
    Expression<String>? slug,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (examType != null) 'exam_type': examType,
      if (slug != null) 'slug': slug,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpecialitiesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? examType,
      Value<String>? slug,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return SpecialitiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      examType: examType ?? this.examType,
      slug: slug ?? this.slug,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (examType.present) {
      map['exam_type'] = Variable<String>(examType.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpecialitiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('examType: $examType, ')
          ..write('slug: $slug, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _specialityIdMeta =
      const VerificationMeta('specialityId');
  @override
  late final GeneratedColumn<String> specialityId = GeneratedColumn<String>(
      'speciality_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _examWeightMeta =
      const VerificationMeta('examWeight');
  @override
  late final GeneratedColumn<int> examWeight = GeneratedColumn<int>(
      'exam_weight', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _contentVersionMeta =
      const VerificationMeta('contentVersion');
  @override
  late final GeneratedColumn<int> contentVersion = GeneratedColumn<int>(
      'content_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, specialityId, title, slug, sortOrder, examWeight, contentVersion];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(Insertable<Chapter> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('speciality_id')) {
      context.handle(
          _specialityIdMeta,
          specialityId.isAcceptableOrUnknown(
              data['speciality_id']!, _specialityIdMeta));
    } else if (isInserting) {
      context.missing(_specialityIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('exam_weight')) {
      context.handle(
          _examWeightMeta,
          examWeight.isAcceptableOrUnknown(
              data['exam_weight']!, _examWeightMeta));
    }
    if (data.containsKey('content_version')) {
      context.handle(
          _contentVersionMeta,
          contentVersion.isAcceptableOrUnknown(
              data['content_version']!, _contentVersionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      specialityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}speciality_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      examWeight: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}exam_weight'])!,
      contentVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}content_version'])!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final String id;
  final String specialityId;
  final String title;
  final String slug;
  final int sortOrder;
  final int examWeight;
  final int contentVersion;
  const Chapter(
      {required this.id,
      required this.specialityId,
      required this.title,
      required this.slug,
      required this.sortOrder,
      required this.examWeight,
      required this.contentVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['speciality_id'] = Variable<String>(specialityId);
    map['title'] = Variable<String>(title);
    map['slug'] = Variable<String>(slug);
    map['sort_order'] = Variable<int>(sortOrder);
    map['exam_weight'] = Variable<int>(examWeight);
    map['content_version'] = Variable<int>(contentVersion);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      specialityId: Value(specialityId),
      title: Value(title),
      slug: Value(slug),
      sortOrder: Value(sortOrder),
      examWeight: Value(examWeight),
      contentVersion: Value(contentVersion),
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<String>(json['id']),
      specialityId: serializer.fromJson<String>(json['specialityId']),
      title: serializer.fromJson<String>(json['title']),
      slug: serializer.fromJson<String>(json['slug']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      examWeight: serializer.fromJson<int>(json['examWeight']),
      contentVersion: serializer.fromJson<int>(json['contentVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'specialityId': serializer.toJson<String>(specialityId),
      'title': serializer.toJson<String>(title),
      'slug': serializer.toJson<String>(slug),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'examWeight': serializer.toJson<int>(examWeight),
      'contentVersion': serializer.toJson<int>(contentVersion),
    };
  }

  Chapter copyWith(
          {String? id,
          String? specialityId,
          String? title,
          String? slug,
          int? sortOrder,
          int? examWeight,
          int? contentVersion}) =>
      Chapter(
        id: id ?? this.id,
        specialityId: specialityId ?? this.specialityId,
        title: title ?? this.title,
        slug: slug ?? this.slug,
        sortOrder: sortOrder ?? this.sortOrder,
        examWeight: examWeight ?? this.examWeight,
        contentVersion: contentVersion ?? this.contentVersion,
      );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      specialityId: data.specialityId.present
          ? data.specialityId.value
          : this.specialityId,
      title: data.title.present ? data.title.value : this.title,
      slug: data.slug.present ? data.slug.value : this.slug,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      examWeight:
          data.examWeight.present ? data.examWeight.value : this.examWeight,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('specialityId: $specialityId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('examWeight: $examWeight, ')
          ..write('contentVersion: $contentVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, specialityId, title, slug, sortOrder, examWeight, contentVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.specialityId == this.specialityId &&
          other.title == this.title &&
          other.slug == this.slug &&
          other.sortOrder == this.sortOrder &&
          other.examWeight == this.examWeight &&
          other.contentVersion == this.contentVersion);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<String> id;
  final Value<String> specialityId;
  final Value<String> title;
  final Value<String> slug;
  final Value<int> sortOrder;
  final Value<int> examWeight;
  final Value<int> contentVersion;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.specialityId = const Value.absent(),
    this.title = const Value.absent(),
    this.slug = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.examWeight = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String id,
    required String specialityId,
    required String title,
    required String slug,
    this.sortOrder = const Value.absent(),
    this.examWeight = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        specialityId = Value(specialityId),
        title = Value(title),
        slug = Value(slug);
  static Insertable<Chapter> custom({
    Expression<String>? id,
    Expression<String>? specialityId,
    Expression<String>? title,
    Expression<String>? slug,
    Expression<int>? sortOrder,
    Expression<int>? examWeight,
    Expression<int>? contentVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (specialityId != null) 'speciality_id': specialityId,
      if (title != null) 'title': title,
      if (slug != null) 'slug': slug,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (examWeight != null) 'exam_weight': examWeight,
      if (contentVersion != null) 'content_version': contentVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith(
      {Value<String>? id,
      Value<String>? specialityId,
      Value<String>? title,
      Value<String>? slug,
      Value<int>? sortOrder,
      Value<int>? examWeight,
      Value<int>? contentVersion,
      Value<int>? rowid}) {
    return ChaptersCompanion(
      id: id ?? this.id,
      specialityId: specialityId ?? this.specialityId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      sortOrder: sortOrder ?? this.sortOrder,
      examWeight: examWeight ?? this.examWeight,
      contentVersion: contentVersion ?? this.contentVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (specialityId.present) {
      map['speciality_id'] = Variable<String>(specialityId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (examWeight.present) {
      map['exam_weight'] = Variable<int>(examWeight.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<int>(contentVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('specialityId: $specialityId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('examWeight: $examWeight, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TopicsTable extends Topics with TableInfo<$TopicsTable, Topic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
      'chapter_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
      'slug', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _examThemeMeta =
      const VerificationMeta('examTheme');
  @override
  late final GeneratedColumn<String> examTheme = GeneratedColumn<String>(
      'exam_theme', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, chapterId, title, slug, examTheme, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topics';
  @override
  VerificationContext validateIntegrity(Insertable<Topic> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
          _slugMeta, slug.isAcceptableOrUnknown(data['slug']!, _slugMeta));
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('exam_theme')) {
      context.handle(_examThemeMeta,
          examTheme.isAcceptableOrUnknown(data['exam_theme']!, _examThemeMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Topic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Topic(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      slug: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slug'])!,
      examTheme: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exam_theme']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $TopicsTable createAlias(String alias) {
    return $TopicsTable(attachedDatabase, alias);
  }
}

class Topic extends DataClass implements Insertable<Topic> {
  final String id;
  final String chapterId;
  final String title;
  final String slug;
  final String? examTheme;
  final int sortOrder;
  const Topic(
      {required this.id,
      required this.chapterId,
      required this.title,
      required this.slug,
      this.examTheme,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chapter_id'] = Variable<String>(chapterId);
    map['title'] = Variable<String>(title);
    map['slug'] = Variable<String>(slug);
    if (!nullToAbsent || examTheme != null) {
      map['exam_theme'] = Variable<String>(examTheme);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TopicsCompanion toCompanion(bool nullToAbsent) {
    return TopicsCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      title: Value(title),
      slug: Value(slug),
      examTheme: examTheme == null && nullToAbsent
          ? const Value.absent()
          : Value(examTheme),
      sortOrder: Value(sortOrder),
    );
  }

  factory Topic.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Topic(
      id: serializer.fromJson<String>(json['id']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      title: serializer.fromJson<String>(json['title']),
      slug: serializer.fromJson<String>(json['slug']),
      examTheme: serializer.fromJson<String?>(json['examTheme']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chapterId': serializer.toJson<String>(chapterId),
      'title': serializer.toJson<String>(title),
      'slug': serializer.toJson<String>(slug),
      'examTheme': serializer.toJson<String?>(examTheme),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Topic copyWith(
          {String? id,
          String? chapterId,
          String? title,
          String? slug,
          Value<String?> examTheme = const Value.absent(),
          int? sortOrder}) =>
      Topic(
        id: id ?? this.id,
        chapterId: chapterId ?? this.chapterId,
        title: title ?? this.title,
        slug: slug ?? this.slug,
        examTheme: examTheme.present ? examTheme.value : this.examTheme,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  Topic copyWithCompanion(TopicsCompanion data) {
    return Topic(
      id: data.id.present ? data.id.value : this.id,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      title: data.title.present ? data.title.value : this.title,
      slug: data.slug.present ? data.slug.value : this.slug,
      examTheme: data.examTheme.present ? data.examTheme.value : this.examTheme,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Topic(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('examTheme: $examTheme, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, chapterId, title, slug, examTheme, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Topic &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.title == this.title &&
          other.slug == this.slug &&
          other.examTheme == this.examTheme &&
          other.sortOrder == this.sortOrder);
}

class TopicsCompanion extends UpdateCompanion<Topic> {
  final Value<String> id;
  final Value<String> chapterId;
  final Value<String> title;
  final Value<String> slug;
  final Value<String?> examTheme;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const TopicsCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.title = const Value.absent(),
    this.slug = const Value.absent(),
    this.examTheme = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TopicsCompanion.insert({
    required String id,
    required String chapterId,
    required String title,
    required String slug,
    this.examTheme = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        chapterId = Value(chapterId),
        title = Value(title),
        slug = Value(slug);
  static Insertable<Topic> custom({
    Expression<String>? id,
    Expression<String>? chapterId,
    Expression<String>? title,
    Expression<String>? slug,
    Expression<String>? examTheme,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (title != null) 'title': title,
      if (slug != null) 'slug': slug,
      if (examTheme != null) 'exam_theme': examTheme,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TopicsCompanion copyWith(
      {Value<String>? id,
      Value<String>? chapterId,
      Value<String>? title,
      Value<String>? slug,
      Value<String?>? examTheme,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return TopicsCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      examTheme: examTheme ?? this.examTheme,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (examTheme.present) {
      map['exam_theme'] = Variable<String>(examTheme.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicsCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('title: $title, ')
          ..write('slug: $slug, ')
          ..write('examTheme: $examTheme, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QnasTable extends Qnas with TableInfo<$QnasTable, Qna> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QnasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _topicIdMeta =
      const VerificationMeta('topicId');
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
      'topic_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _questionMeta =
      const VerificationMeta('question');
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
      'question', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _yearsMeta = const VerificationMeta('years');
  @override
  late final GeneratedColumn<String> years = GeneratedColumn<String>(
      'years', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _marksMeta = const VerificationMeta('marks');
  @override
  late final GeneratedColumn<int> marks = GeneratedColumn<int>(
      'marks', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _earnsMarksMeta =
      const VerificationMeta('earnsMarks');
  @override
  late final GeneratedColumn<String> earnsMarks = GeneratedColumn<String>(
      'earns_marks', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sectionsMeta =
      const VerificationMeta('sections');
  @override
  late final GeneratedColumn<String> sections = GeneratedColumn<String>(
      'sections', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, topicId, question, years, marks, earnsMarks, sections, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qnas';
  @override
  VerificationContext validateIntegrity(Insertable<Qna> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(_topicIdMeta,
          topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta));
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(_questionMeta,
          question.isAcceptableOrUnknown(data['question']!, _questionMeta));
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('years')) {
      context.handle(
          _yearsMeta, years.isAcceptableOrUnknown(data['years']!, _yearsMeta));
    }
    if (data.containsKey('marks')) {
      context.handle(
          _marksMeta, marks.isAcceptableOrUnknown(data['marks']!, _marksMeta));
    }
    if (data.containsKey('earns_marks')) {
      context.handle(
          _earnsMarksMeta,
          earnsMarks.isAcceptableOrUnknown(
              data['earns_marks']!, _earnsMarksMeta));
    } else if (isInserting) {
      context.missing(_earnsMarksMeta);
    }
    if (data.containsKey('sections')) {
      context.handle(_sectionsMeta,
          sections.isAcceptableOrUnknown(data['sections']!, _sectionsMeta));
    } else if (isInserting) {
      context.missing(_sectionsMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Qna map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Qna(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      topicId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}topic_id'])!,
      question: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}question'])!,
      years: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}years']),
      marks: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}marks']),
      earnsMarks: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}earns_marks'])!,
      sections: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sections'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $QnasTable createAlias(String alias) {
    return $QnasTable(attachedDatabase, alias);
  }
}

class Qna extends DataClass implements Insertable<Qna> {
  final String id;
  final String topicId;
  final String question;
  final String? years;
  final int? marks;
  final String earnsMarks;
  final String sections;
  final int sortOrder;
  const Qna(
      {required this.id,
      required this.topicId,
      required this.question,
      this.years,
      this.marks,
      required this.earnsMarks,
      required this.sections,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['topic_id'] = Variable<String>(topicId);
    map['question'] = Variable<String>(question);
    if (!nullToAbsent || years != null) {
      map['years'] = Variable<String>(years);
    }
    if (!nullToAbsent || marks != null) {
      map['marks'] = Variable<int>(marks);
    }
    map['earns_marks'] = Variable<String>(earnsMarks);
    map['sections'] = Variable<String>(sections);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  QnasCompanion toCompanion(bool nullToAbsent) {
    return QnasCompanion(
      id: Value(id),
      topicId: Value(topicId),
      question: Value(question),
      years:
          years == null && nullToAbsent ? const Value.absent() : Value(years),
      marks:
          marks == null && nullToAbsent ? const Value.absent() : Value(marks),
      earnsMarks: Value(earnsMarks),
      sections: Value(sections),
      sortOrder: Value(sortOrder),
    );
  }

  factory Qna.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Qna(
      id: serializer.fromJson<String>(json['id']),
      topicId: serializer.fromJson<String>(json['topicId']),
      question: serializer.fromJson<String>(json['question']),
      years: serializer.fromJson<String?>(json['years']),
      marks: serializer.fromJson<int?>(json['marks']),
      earnsMarks: serializer.fromJson<String>(json['earnsMarks']),
      sections: serializer.fromJson<String>(json['sections']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'topicId': serializer.toJson<String>(topicId),
      'question': serializer.toJson<String>(question),
      'years': serializer.toJson<String?>(years),
      'marks': serializer.toJson<int?>(marks),
      'earnsMarks': serializer.toJson<String>(earnsMarks),
      'sections': serializer.toJson<String>(sections),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Qna copyWith(
          {String? id,
          String? topicId,
          String? question,
          Value<String?> years = const Value.absent(),
          Value<int?> marks = const Value.absent(),
          String? earnsMarks,
          String? sections,
          int? sortOrder}) =>
      Qna(
        id: id ?? this.id,
        topicId: topicId ?? this.topicId,
        question: question ?? this.question,
        years: years.present ? years.value : this.years,
        marks: marks.present ? marks.value : this.marks,
        earnsMarks: earnsMarks ?? this.earnsMarks,
        sections: sections ?? this.sections,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  Qna copyWithCompanion(QnasCompanion data) {
    return Qna(
      id: data.id.present ? data.id.value : this.id,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      question: data.question.present ? data.question.value : this.question,
      years: data.years.present ? data.years.value : this.years,
      marks: data.marks.present ? data.marks.value : this.marks,
      earnsMarks:
          data.earnsMarks.present ? data.earnsMarks.value : this.earnsMarks,
      sections: data.sections.present ? data.sections.value : this.sections,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Qna(')
          ..write('id: $id, ')
          ..write('topicId: $topicId, ')
          ..write('question: $question, ')
          ..write('years: $years, ')
          ..write('marks: $marks, ')
          ..write('earnsMarks: $earnsMarks, ')
          ..write('sections: $sections, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, topicId, question, years, marks, earnsMarks, sections, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Qna &&
          other.id == this.id &&
          other.topicId == this.topicId &&
          other.question == this.question &&
          other.years == this.years &&
          other.marks == this.marks &&
          other.earnsMarks == this.earnsMarks &&
          other.sections == this.sections &&
          other.sortOrder == this.sortOrder);
}

class QnasCompanion extends UpdateCompanion<Qna> {
  final Value<String> id;
  final Value<String> topicId;
  final Value<String> question;
  final Value<String?> years;
  final Value<int?> marks;
  final Value<String> earnsMarks;
  final Value<String> sections;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const QnasCompanion({
    this.id = const Value.absent(),
    this.topicId = const Value.absent(),
    this.question = const Value.absent(),
    this.years = const Value.absent(),
    this.marks = const Value.absent(),
    this.earnsMarks = const Value.absent(),
    this.sections = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QnasCompanion.insert({
    required String id,
    required String topicId,
    required String question,
    this.years = const Value.absent(),
    this.marks = const Value.absent(),
    required String earnsMarks,
    required String sections,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        topicId = Value(topicId),
        question = Value(question),
        earnsMarks = Value(earnsMarks),
        sections = Value(sections);
  static Insertable<Qna> custom({
    Expression<String>? id,
    Expression<String>? topicId,
    Expression<String>? question,
    Expression<String>? years,
    Expression<int>? marks,
    Expression<String>? earnsMarks,
    Expression<String>? sections,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (topicId != null) 'topic_id': topicId,
      if (question != null) 'question': question,
      if (years != null) 'years': years,
      if (marks != null) 'marks': marks,
      if (earnsMarks != null) 'earns_marks': earnsMarks,
      if (sections != null) 'sections': sections,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QnasCompanion copyWith(
      {Value<String>? id,
      Value<String>? topicId,
      Value<String>? question,
      Value<String?>? years,
      Value<int?>? marks,
      Value<String>? earnsMarks,
      Value<String>? sections,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return QnasCompanion(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      question: question ?? this.question,
      years: years ?? this.years,
      marks: marks ?? this.marks,
      earnsMarks: earnsMarks ?? this.earnsMarks,
      sections: sections ?? this.sections,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (years.present) {
      map['years'] = Variable<String>(years.value);
    }
    if (marks.present) {
      map['marks'] = Variable<int>(marks.value);
    }
    if (earnsMarks.present) {
      map['earns_marks'] = Variable<String>(earnsMarks.value);
    }
    if (sections.present) {
      map['sections'] = Variable<String>(sections.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QnasCompanion(')
          ..write('id: $id, ')
          ..write('topicId: $topicId, ')
          ..write('question: $question, ')
          ..write('years: $years, ')
          ..write('marks: $marks, ')
          ..write('earnsMarks: $earnsMarks, ')
          ..write('sections: $sections, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImagesTable extends Images with TableInfo<$ImagesTable, Image> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _qnaIdMeta = const VerificationMeta('qnaId');
  @override
  late final GeneratedColumn<String> qnaId = GeneratedColumn<String>(
      'qna_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _captionMeta =
      const VerificationMeta('caption');
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
      'caption', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentDescriptionMeta =
      const VerificationMeta('contentDescription');
  @override
  late final GeneratedColumn<String> contentDescription =
      GeneratedColumn<String>('content_description', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _byteSizeMeta =
      const VerificationMeta('byteSize');
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
      'byte_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
      'sha256', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, qnaId, caption, contentDescription, byteSize, sha256, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'images';
  @override
  VerificationContext validateIntegrity(Insertable<Image> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('qna_id')) {
      context.handle(
          _qnaIdMeta, qnaId.isAcceptableOrUnknown(data['qna_id']!, _qnaIdMeta));
    } else if (isInserting) {
      context.missing(_qnaIdMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(_captionMeta,
          caption.isAcceptableOrUnknown(data['caption']!, _captionMeta));
    } else if (isInserting) {
      context.missing(_captionMeta);
    }
    if (data.containsKey('content_description')) {
      context.handle(
          _contentDescriptionMeta,
          contentDescription.isAcceptableOrUnknown(
              data['content_description']!, _contentDescriptionMeta));
    } else if (isInserting) {
      context.missing(_contentDescriptionMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(_byteSizeMeta,
          byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta));
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(_sha256Meta,
          sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta));
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Image map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Image(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      qnaId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}qna_id'])!,
      caption: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}caption'])!,
      contentDescription: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}content_description'])!,
      byteSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}byte_size'])!,
      sha256: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $ImagesTable createAlias(String alias) {
    return $ImagesTable(attachedDatabase, alias);
  }
}

class Image extends DataClass implements Insertable<Image> {
  final String id;
  final String qnaId;
  final String caption;
  final String contentDescription;
  final int byteSize;
  final String sha256;
  final int sortOrder;
  const Image(
      {required this.id,
      required this.qnaId,
      required this.caption,
      required this.contentDescription,
      required this.byteSize,
      required this.sha256,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['qna_id'] = Variable<String>(qnaId);
    map['caption'] = Variable<String>(caption);
    map['content_description'] = Variable<String>(contentDescription);
    map['byte_size'] = Variable<int>(byteSize);
    map['sha256'] = Variable<String>(sha256);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ImagesCompanion toCompanion(bool nullToAbsent) {
    return ImagesCompanion(
      id: Value(id),
      qnaId: Value(qnaId),
      caption: Value(caption),
      contentDescription: Value(contentDescription),
      byteSize: Value(byteSize),
      sha256: Value(sha256),
      sortOrder: Value(sortOrder),
    );
  }

  factory Image.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Image(
      id: serializer.fromJson<String>(json['id']),
      qnaId: serializer.fromJson<String>(json['qnaId']),
      caption: serializer.fromJson<String>(json['caption']),
      contentDescription:
          serializer.fromJson<String>(json['contentDescription']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      sha256: serializer.fromJson<String>(json['sha256']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'qnaId': serializer.toJson<String>(qnaId),
      'caption': serializer.toJson<String>(caption),
      'contentDescription': serializer.toJson<String>(contentDescription),
      'byteSize': serializer.toJson<int>(byteSize),
      'sha256': serializer.toJson<String>(sha256),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Image copyWith(
          {String? id,
          String? qnaId,
          String? caption,
          String? contentDescription,
          int? byteSize,
          String? sha256,
          int? sortOrder}) =>
      Image(
        id: id ?? this.id,
        qnaId: qnaId ?? this.qnaId,
        caption: caption ?? this.caption,
        contentDescription: contentDescription ?? this.contentDescription,
        byteSize: byteSize ?? this.byteSize,
        sha256: sha256 ?? this.sha256,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  Image copyWithCompanion(ImagesCompanion data) {
    return Image(
      id: data.id.present ? data.id.value : this.id,
      qnaId: data.qnaId.present ? data.qnaId.value : this.qnaId,
      caption: data.caption.present ? data.caption.value : this.caption,
      contentDescription: data.contentDescription.present
          ? data.contentDescription.value
          : this.contentDescription,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Image(')
          ..write('id: $id, ')
          ..write('qnaId: $qnaId, ')
          ..write('caption: $caption, ')
          ..write('contentDescription: $contentDescription, ')
          ..write('byteSize: $byteSize, ')
          ..write('sha256: $sha256, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, qnaId, caption, contentDescription, byteSize, sha256, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Image &&
          other.id == this.id &&
          other.qnaId == this.qnaId &&
          other.caption == this.caption &&
          other.contentDescription == this.contentDescription &&
          other.byteSize == this.byteSize &&
          other.sha256 == this.sha256 &&
          other.sortOrder == this.sortOrder);
}

class ImagesCompanion extends UpdateCompanion<Image> {
  final Value<String> id;
  final Value<String> qnaId;
  final Value<String> caption;
  final Value<String> contentDescription;
  final Value<int> byteSize;
  final Value<String> sha256;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ImagesCompanion({
    this.id = const Value.absent(),
    this.qnaId = const Value.absent(),
    this.caption = const Value.absent(),
    this.contentDescription = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImagesCompanion.insert({
    required String id,
    required String qnaId,
    required String caption,
    required String contentDescription,
    required int byteSize,
    required String sha256,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        qnaId = Value(qnaId),
        caption = Value(caption),
        contentDescription = Value(contentDescription),
        byteSize = Value(byteSize),
        sha256 = Value(sha256);
  static Insertable<Image> custom({
    Expression<String>? id,
    Expression<String>? qnaId,
    Expression<String>? caption,
    Expression<String>? contentDescription,
    Expression<int>? byteSize,
    Expression<String>? sha256,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (qnaId != null) 'qna_id': qnaId,
      if (caption != null) 'caption': caption,
      if (contentDescription != null) 'content_description': contentDescription,
      if (byteSize != null) 'byte_size': byteSize,
      if (sha256 != null) 'sha256': sha256,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? qnaId,
      Value<String>? caption,
      Value<String>? contentDescription,
      Value<int>? byteSize,
      Value<String>? sha256,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return ImagesCompanion(
      id: id ?? this.id,
      qnaId: qnaId ?? this.qnaId,
      caption: caption ?? this.caption,
      contentDescription: contentDescription ?? this.contentDescription,
      byteSize: byteSize ?? this.byteSize,
      sha256: sha256 ?? this.sha256,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (qnaId.present) {
      map['qna_id'] = Variable<String>(qnaId.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (contentDescription.present) {
      map['content_description'] = Variable<String>(contentDescription.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImagesCompanion(')
          ..write('id: $id, ')
          ..write('qnaId: $qnaId, ')
          ..write('caption: $caption, ')
          ..write('contentDescription: $contentDescription, ')
          ..write('byteSize: $byteSize, ')
          ..write('sha256: $sha256, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImageBlobsTable extends ImageBlobs
    with TableInfo<$ImageBlobsTable, ImageBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _imageIdMeta =
      const VerificationMeta('imageId');
  @override
  late final GeneratedColumn<String> imageId = GeneratedColumn<String>(
      'image_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
      'bytes', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
      'sha256', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [imageId, bytes, sha256];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_blobs';
  @override
  VerificationContext validateIntegrity(Insertable<ImageBlob> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('image_id')) {
      context.handle(_imageIdMeta,
          imageId.isAcceptableOrUnknown(data['image_id']!, _imageIdMeta));
    } else if (isInserting) {
      context.missing(_imageIdMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
          _bytesMeta, bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta));
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(_sha256Meta,
          sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta));
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {imageId};
  @override
  ImageBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageBlob(
      imageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_id'])!,
      bytes: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}bytes'])!,
      sha256: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256'])!,
    );
  }

  @override
  $ImageBlobsTable createAlias(String alias) {
    return $ImageBlobsTable(attachedDatabase, alias);
  }
}

class ImageBlob extends DataClass implements Insertable<ImageBlob> {
  final String imageId;
  final Uint8List bytes;
  final String sha256;
  const ImageBlob(
      {required this.imageId, required this.bytes, required this.sha256});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['image_id'] = Variable<String>(imageId);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['sha256'] = Variable<String>(sha256);
    return map;
  }

  ImageBlobsCompanion toCompanion(bool nullToAbsent) {
    return ImageBlobsCompanion(
      imageId: Value(imageId),
      bytes: Value(bytes),
      sha256: Value(sha256),
    );
  }

  factory ImageBlob.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageBlob(
      imageId: serializer.fromJson<String>(json['imageId']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      sha256: serializer.fromJson<String>(json['sha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'imageId': serializer.toJson<String>(imageId),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'sha256': serializer.toJson<String>(sha256),
    };
  }

  ImageBlob copyWith({String? imageId, Uint8List? bytes, String? sha256}) =>
      ImageBlob(
        imageId: imageId ?? this.imageId,
        bytes: bytes ?? this.bytes,
        sha256: sha256 ?? this.sha256,
      );
  ImageBlob copyWithCompanion(ImageBlobsCompanion data) {
    return ImageBlob(
      imageId: data.imageId.present ? data.imageId.value : this.imageId,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageBlob(')
          ..write('imageId: $imageId, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(imageId, $driftBlobEquality.hash(bytes), sha256);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageBlob &&
          other.imageId == this.imageId &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.sha256 == this.sha256);
}

class ImageBlobsCompanion extends UpdateCompanion<ImageBlob> {
  final Value<String> imageId;
  final Value<Uint8List> bytes;
  final Value<String> sha256;
  final Value<int> rowid;
  const ImageBlobsCompanion({
    this.imageId = const Value.absent(),
    this.bytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageBlobsCompanion.insert({
    required String imageId,
    required Uint8List bytes,
    required String sha256,
    this.rowid = const Value.absent(),
  })  : imageId = Value(imageId),
        bytes = Value(bytes),
        sha256 = Value(sha256);
  static Insertable<ImageBlob> custom({
    Expression<String>? imageId,
    Expression<Uint8List>? bytes,
    Expression<String>? sha256,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (imageId != null) 'image_id': imageId,
      if (bytes != null) 'bytes': bytes,
      if (sha256 != null) 'sha256': sha256,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageBlobsCompanion copyWith(
      {Value<String>? imageId,
      Value<Uint8List>? bytes,
      Value<String>? sha256,
      Value<int>? rowid}) {
    return ImageBlobsCompanion(
      imageId: imageId ?? this.imageId,
      bytes: bytes ?? this.bytes,
      sha256: sha256 ?? this.sha256,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (imageId.present) {
      map['image_id'] = Variable<String>(imageId.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageBlobsCompanion(')
          ..write('imageId: $imageId, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingReviewEventsTable extends PendingReviewEvents
    with TableInfo<$PendingReviewEventsTable, PendingReviewEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingReviewEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
      'rating', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shownAtMeta =
      const VerificationMeta('shownAt');
  @override
  late final GeneratedColumn<DateTime> shownAt = GeneratedColumn<DateTime>(
      'shown_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _revealedAtMeta =
      const VerificationMeta('revealedAt');
  @override
  late final GeneratedColumn<DateTime> revealedAt = GeneratedColumn<DateTime>(
      'revealed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _ratedAtMeta =
      const VerificationMeta('ratedAt');
  @override
  late final GeneratedColumn<DateTime> ratedAt = GeneratedColumn<DateTime>(
      'rated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _localDayMeta =
      const VerificationMeta('localDay');
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
      'local_day', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, contentId, rating, shownAt, revealedAt, ratedAt, localDay, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_review_events';
  @override
  VerificationContext validateIntegrity(Insertable<PendingReviewEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('shown_at')) {
      context.handle(_shownAtMeta,
          shownAt.isAcceptableOrUnknown(data['shown_at']!, _shownAtMeta));
    } else if (isInserting) {
      context.missing(_shownAtMeta);
    }
    if (data.containsKey('revealed_at')) {
      context.handle(
          _revealedAtMeta,
          revealedAt.isAcceptableOrUnknown(
              data['revealed_at']!, _revealedAtMeta));
    } else if (isInserting) {
      context.missing(_revealedAtMeta);
    }
    if (data.containsKey('rated_at')) {
      context.handle(_ratedAtMeta,
          ratedAt.isAcceptableOrUnknown(data['rated_at']!, _ratedAtMeta));
    } else if (isInserting) {
      context.missing(_ratedAtMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(_localDayMeta,
          localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta));
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingReviewEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingReviewEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rating'])!,
      shownAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}shown_at'])!,
      revealedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}revealed_at'])!,
      ratedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}rated_at'])!,
      localDay: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_day'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $PendingReviewEventsTable createAlias(String alias) {
    return $PendingReviewEventsTable(attachedDatabase, alias);
  }
}

class PendingReviewEvent extends DataClass
    implements Insertable<PendingReviewEvent> {
  final String id;
  final String contentId;
  final String rating;
  final DateTime shownAt;
  final DateTime revealedAt;
  final DateTime ratedAt;
  final String localDay;
  final DateTime? syncedAt;
  const PendingReviewEvent(
      {required this.id,
      required this.contentId,
      required this.rating,
      required this.shownAt,
      required this.revealedAt,
      required this.ratedAt,
      required this.localDay,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['content_id'] = Variable<String>(contentId);
    map['rating'] = Variable<String>(rating);
    map['shown_at'] = Variable<DateTime>(shownAt);
    map['revealed_at'] = Variable<DateTime>(revealedAt);
    map['rated_at'] = Variable<DateTime>(ratedAt);
    map['local_day'] = Variable<String>(localDay);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  PendingReviewEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingReviewEventsCompanion(
      id: Value(id),
      contentId: Value(contentId),
      rating: Value(rating),
      shownAt: Value(shownAt),
      revealedAt: Value(revealedAt),
      ratedAt: Value(ratedAt),
      localDay: Value(localDay),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory PendingReviewEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingReviewEvent(
      id: serializer.fromJson<String>(json['id']),
      contentId: serializer.fromJson<String>(json['contentId']),
      rating: serializer.fromJson<String>(json['rating']),
      shownAt: serializer.fromJson<DateTime>(json['shownAt']),
      revealedAt: serializer.fromJson<DateTime>(json['revealedAt']),
      ratedAt: serializer.fromJson<DateTime>(json['ratedAt']),
      localDay: serializer.fromJson<String>(json['localDay']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'contentId': serializer.toJson<String>(contentId),
      'rating': serializer.toJson<String>(rating),
      'shownAt': serializer.toJson<DateTime>(shownAt),
      'revealedAt': serializer.toJson<DateTime>(revealedAt),
      'ratedAt': serializer.toJson<DateTime>(ratedAt),
      'localDay': serializer.toJson<String>(localDay),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  PendingReviewEvent copyWith(
          {String? id,
          String? contentId,
          String? rating,
          DateTime? shownAt,
          DateTime? revealedAt,
          DateTime? ratedAt,
          String? localDay,
          Value<DateTime?> syncedAt = const Value.absent()}) =>
      PendingReviewEvent(
        id: id ?? this.id,
        contentId: contentId ?? this.contentId,
        rating: rating ?? this.rating,
        shownAt: shownAt ?? this.shownAt,
        revealedAt: revealedAt ?? this.revealedAt,
        ratedAt: ratedAt ?? this.ratedAt,
        localDay: localDay ?? this.localDay,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  PendingReviewEvent copyWithCompanion(PendingReviewEventsCompanion data) {
    return PendingReviewEvent(
      id: data.id.present ? data.id.value : this.id,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      rating: data.rating.present ? data.rating.value : this.rating,
      shownAt: data.shownAt.present ? data.shownAt.value : this.shownAt,
      revealedAt:
          data.revealedAt.present ? data.revealedAt.value : this.revealedAt,
      ratedAt: data.ratedAt.present ? data.ratedAt.value : this.ratedAt,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingReviewEvent(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('rating: $rating, ')
          ..write('shownAt: $shownAt, ')
          ..write('revealedAt: $revealedAt, ')
          ..write('ratedAt: $ratedAt, ')
          ..write('localDay: $localDay, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, contentId, rating, shownAt, revealedAt, ratedAt, localDay, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingReviewEvent &&
          other.id == this.id &&
          other.contentId == this.contentId &&
          other.rating == this.rating &&
          other.shownAt == this.shownAt &&
          other.revealedAt == this.revealedAt &&
          other.ratedAt == this.ratedAt &&
          other.localDay == this.localDay &&
          other.syncedAt == this.syncedAt);
}

class PendingReviewEventsCompanion extends UpdateCompanion<PendingReviewEvent> {
  final Value<String> id;
  final Value<String> contentId;
  final Value<String> rating;
  final Value<DateTime> shownAt;
  final Value<DateTime> revealedAt;
  final Value<DateTime> ratedAt;
  final Value<String> localDay;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const PendingReviewEventsCompanion({
    this.id = const Value.absent(),
    this.contentId = const Value.absent(),
    this.rating = const Value.absent(),
    this.shownAt = const Value.absent(),
    this.revealedAt = const Value.absent(),
    this.ratedAt = const Value.absent(),
    this.localDay = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingReviewEventsCompanion.insert({
    required String id,
    required String contentId,
    required String rating,
    required DateTime shownAt,
    required DateTime revealedAt,
    required DateTime ratedAt,
    required String localDay,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        contentId = Value(contentId),
        rating = Value(rating),
        shownAt = Value(shownAt),
        revealedAt = Value(revealedAt),
        ratedAt = Value(ratedAt),
        localDay = Value(localDay);
  static Insertable<PendingReviewEvent> custom({
    Expression<String>? id,
    Expression<String>? contentId,
    Expression<String>? rating,
    Expression<DateTime>? shownAt,
    Expression<DateTime>? revealedAt,
    Expression<DateTime>? ratedAt,
    Expression<String>? localDay,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentId != null) 'content_id': contentId,
      if (rating != null) 'rating': rating,
      if (shownAt != null) 'shown_at': shownAt,
      if (revealedAt != null) 'revealed_at': revealedAt,
      if (ratedAt != null) 'rated_at': ratedAt,
      if (localDay != null) 'local_day': localDay,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingReviewEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? contentId,
      Value<String>? rating,
      Value<DateTime>? shownAt,
      Value<DateTime>? revealedAt,
      Value<DateTime>? ratedAt,
      Value<String>? localDay,
      Value<DateTime?>? syncedAt,
      Value<int>? rowid}) {
    return PendingReviewEventsCompanion(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      rating: rating ?? this.rating,
      shownAt: shownAt ?? this.shownAt,
      revealedAt: revealedAt ?? this.revealedAt,
      ratedAt: ratedAt ?? this.ratedAt,
      localDay: localDay ?? this.localDay,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (shownAt.present) {
      map['shown_at'] = Variable<DateTime>(shownAt.value);
    }
    if (revealedAt.present) {
      map['revealed_at'] = Variable<DateTime>(revealedAt.value);
    }
    if (ratedAt.present) {
      map['rated_at'] = Variable<DateTime>(ratedAt.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingReviewEventsCompanion(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('rating: $rating, ')
          ..write('shownAt: $shownAt, ')
          ..write('revealedAt: $revealedAt, ')
          ..write('ratedAt: $ratedAt, ')
          ..write('localDay: $localDay, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingAppEventsTable extends PendingAppEvents
    with TableInfo<$PendingAppEventsTable, PendingAppEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingAppEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _hiddenMsMeta =
      const VerificationMeta('hiddenMs');
  @override
  late final GeneratedColumn<int> hiddenMs = GeneratedColumn<int>(
      'hidden_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _localDayMeta =
      const VerificationMeta('localDay');
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
      'local_day', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, eventType, contentId, hiddenMs, occurredAt, localDay, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_app_events';
  @override
  VerificationContext validateIntegrity(Insertable<PendingAppEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    }
    if (data.containsKey('hidden_ms')) {
      context.handle(_hiddenMsMeta,
          hiddenMs.isAcceptableOrUnknown(data['hidden_ms']!, _hiddenMsMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(_localDayMeta,
          localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta));
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAppEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAppEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id']),
      hiddenMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hidden_ms']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      localDay: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_day'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $PendingAppEventsTable createAlias(String alias) {
    return $PendingAppEventsTable(attachedDatabase, alias);
  }
}

class PendingAppEvent extends DataClass implements Insertable<PendingAppEvent> {
  final String id;
  final String eventType;
  final String? contentId;
  final int? hiddenMs;
  final DateTime occurredAt;
  final String localDay;
  final DateTime? syncedAt;
  const PendingAppEvent(
      {required this.id,
      required this.eventType,
      this.contentId,
      this.hiddenMs,
      required this.occurredAt,
      required this.localDay,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || contentId != null) {
      map['content_id'] = Variable<String>(contentId);
    }
    if (!nullToAbsent || hiddenMs != null) {
      map['hidden_ms'] = Variable<int>(hiddenMs);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['local_day'] = Variable<String>(localDay);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  PendingAppEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingAppEventsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      contentId: contentId == null && nullToAbsent
          ? const Value.absent()
          : Value(contentId),
      hiddenMs: hiddenMs == null && nullToAbsent
          ? const Value.absent()
          : Value(hiddenMs),
      occurredAt: Value(occurredAt),
      localDay: Value(localDay),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory PendingAppEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAppEvent(
      id: serializer.fromJson<String>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      contentId: serializer.fromJson<String?>(json['contentId']),
      hiddenMs: serializer.fromJson<int?>(json['hiddenMs']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      localDay: serializer.fromJson<String>(json['localDay']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventType': serializer.toJson<String>(eventType),
      'contentId': serializer.toJson<String?>(contentId),
      'hiddenMs': serializer.toJson<int?>(hiddenMs),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'localDay': serializer.toJson<String>(localDay),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  PendingAppEvent copyWith(
          {String? id,
          String? eventType,
          Value<String?> contentId = const Value.absent(),
          Value<int?> hiddenMs = const Value.absent(),
          DateTime? occurredAt,
          String? localDay,
          Value<DateTime?> syncedAt = const Value.absent()}) =>
      PendingAppEvent(
        id: id ?? this.id,
        eventType: eventType ?? this.eventType,
        contentId: contentId.present ? contentId.value : this.contentId,
        hiddenMs: hiddenMs.present ? hiddenMs.value : this.hiddenMs,
        occurredAt: occurredAt ?? this.occurredAt,
        localDay: localDay ?? this.localDay,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  PendingAppEvent copyWithCompanion(PendingAppEventsCompanion data) {
    return PendingAppEvent(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      hiddenMs: data.hiddenMs.present ? data.hiddenMs.value : this.hiddenMs,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAppEvent(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('contentId: $contentId, ')
          ..write('hiddenMs: $hiddenMs, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('localDay: $localDay, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, eventType, contentId, hiddenMs, occurredAt, localDay, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAppEvent &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.contentId == this.contentId &&
          other.hiddenMs == this.hiddenMs &&
          other.occurredAt == this.occurredAt &&
          other.localDay == this.localDay &&
          other.syncedAt == this.syncedAt);
}

class PendingAppEventsCompanion extends UpdateCompanion<PendingAppEvent> {
  final Value<String> id;
  final Value<String> eventType;
  final Value<String?> contentId;
  final Value<int?> hiddenMs;
  final Value<DateTime> occurredAt;
  final Value<String> localDay;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const PendingAppEventsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.contentId = const Value.absent(),
    this.hiddenMs = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.localDay = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingAppEventsCompanion.insert({
    required String id,
    required String eventType,
    this.contentId = const Value.absent(),
    this.hiddenMs = const Value.absent(),
    required DateTime occurredAt,
    required String localDay,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        eventType = Value(eventType),
        occurredAt = Value(occurredAt),
        localDay = Value(localDay);
  static Insertable<PendingAppEvent> custom({
    Expression<String>? id,
    Expression<String>? eventType,
    Expression<String>? contentId,
    Expression<int>? hiddenMs,
    Expression<DateTime>? occurredAt,
    Expression<String>? localDay,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (contentId != null) 'content_id': contentId,
      if (hiddenMs != null) 'hidden_ms': hiddenMs,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (localDay != null) 'local_day': localDay,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingAppEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? eventType,
      Value<String?>? contentId,
      Value<int?>? hiddenMs,
      Value<DateTime>? occurredAt,
      Value<String>? localDay,
      Value<DateTime?>? syncedAt,
      Value<int>? rowid}) {
    return PendingAppEventsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      contentId: contentId ?? this.contentId,
      hiddenMs: hiddenMs ?? this.hiddenMs,
      occurredAt: occurredAt ?? this.occurredAt,
      localDay: localDay ?? this.localDay,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (hiddenMs.present) {
      map['hidden_ms'] = Variable<int>(hiddenMs.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingAppEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('contentId: $contentId, ')
          ..write('hiddenMs: $hiddenMs, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('localDay: $localDay, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [contentId, updatedAt, deleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(Insertable<Bookmark> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String contentId;
  final DateTime updatedAt;
  final bool deleted;
  const Bookmark(
      {required this.contentId,
      required this.updatedAt,
      required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      contentId: Value(contentId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory Bookmark.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      contentId: serializer.fromJson<String>(json['contentId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Bookmark copyWith({String? contentId, DateTime? updatedAt, bool? deleted}) =>
      Bookmark(
        contentId: contentId ?? this.contentId,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('contentId: $contentId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(contentId, updatedAt, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.contentId == this.contentId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> contentId;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.contentId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String contentId,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : contentId = Value(contentId),
        updatedAt = Value(updatedAt);
  static Insertable<Bookmark> custom({
    Expression<String>? contentId,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith(
      {Value<String>? contentId,
      Value<DateTime>? updatedAt,
      Value<bool>? deleted,
      Value<int>? rowid}) {
    return BookmarksCompanion(
      contentId: contentId ?? this.contentId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('contentId: $contentId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedChaptersTable extends CachedChapters
    with TableInfo<$CachedChaptersTable, CachedChapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chapterIdMeta =
      const VerificationMeta('chapterId');
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
      'chapter_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentVersionMeta =
      const VerificationMeta('contentVersion');
  @override
  late final GeneratedColumn<int> contentVersion = GeneratedColumn<int>(
      'content_version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [chapterId, contentVersion, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_chapters';
  @override
  VerificationContext validateIntegrity(Insertable<CachedChapter> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chapter_id')) {
      context.handle(_chapterIdMeta,
          chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta));
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('content_version')) {
      context.handle(
          _contentVersionMeta,
          contentVersion.isAcceptableOrUnknown(
              data['content_version']!, _contentVersionMeta));
    } else if (isInserting) {
      context.missing(_contentVersionMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chapterId};
  @override
  CachedChapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedChapter(
      chapterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_id'])!,
      contentVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}content_version'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedChaptersTable createAlias(String alias) {
    return $CachedChaptersTable(attachedDatabase, alias);
  }
}

class CachedChapter extends DataClass implements Insertable<CachedChapter> {
  final String chapterId;
  final int contentVersion;
  final DateTime cachedAt;
  const CachedChapter(
      {required this.chapterId,
      required this.contentVersion,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chapter_id'] = Variable<String>(chapterId);
    map['content_version'] = Variable<int>(contentVersion);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedChaptersCompanion toCompanion(bool nullToAbsent) {
    return CachedChaptersCompanion(
      chapterId: Value(chapterId),
      contentVersion: Value(contentVersion),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedChapter.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedChapter(
      chapterId: serializer.fromJson<String>(json['chapterId']),
      contentVersion: serializer.fromJson<int>(json['contentVersion']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chapterId': serializer.toJson<String>(chapterId),
      'contentVersion': serializer.toJson<int>(contentVersion),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedChapter copyWith(
          {String? chapterId, int? contentVersion, DateTime? cachedAt}) =>
      CachedChapter(
        chapterId: chapterId ?? this.chapterId,
        contentVersion: contentVersion ?? this.contentVersion,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedChapter copyWithCompanion(CachedChaptersCompanion data) {
    return CachedChapter(
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedChapter(')
          ..write('chapterId: $chapterId, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chapterId, contentVersion, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedChapter &&
          other.chapterId == this.chapterId &&
          other.contentVersion == this.contentVersion &&
          other.cachedAt == this.cachedAt);
}

class CachedChaptersCompanion extends UpdateCompanion<CachedChapter> {
  final Value<String> chapterId;
  final Value<int> contentVersion;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedChaptersCompanion({
    this.chapterId = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedChaptersCompanion.insert({
    required String chapterId,
    required int contentVersion,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : chapterId = Value(chapterId),
        contentVersion = Value(contentVersion),
        cachedAt = Value(cachedAt);
  static Insertable<CachedChapter> custom({
    Expression<String>? chapterId,
    Expression<int>? contentVersion,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chapterId != null) 'chapter_id': chapterId,
      if (contentVersion != null) 'content_version': contentVersion,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedChaptersCompanion copyWith(
      {Value<String>? chapterId,
      Value<int>? contentVersion,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return CachedChaptersCompanion(
      chapterId: chapterId ?? this.chapterId,
      contentVersion: contentVersion ?? this.contentVersion,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<int>(contentVersion.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedChaptersCompanion(')
          ..write('chapterId: $chapterId, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSettingsTable extends LocalSettings
    with TableInfo<$LocalSettingsTable, LocalSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_settings';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $LocalSettingsTable createAlias(String alias) {
    return $LocalSettingsTable(attachedDatabase, alias);
  }
}

class LocalSetting extends DataClass implements Insertable<LocalSetting> {
  final String key;
  final String value;
  const LocalSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory LocalSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalSetting copyWith({String? key, String? value}) => LocalSetting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  LocalSetting copyWithCompanion(LocalSettingsCompanion data) {
    return LocalSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalSettingsCompanion extends UpdateCompanion<LocalSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<LocalSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return LocalSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SpecialitiesTable specialities = $SpecialitiesTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $TopicsTable topics = $TopicsTable(this);
  late final $QnasTable qnas = $QnasTable(this);
  late final $ImagesTable images = $ImagesTable(this);
  late final $ImageBlobsTable imageBlobs = $ImageBlobsTable(this);
  late final $PendingReviewEventsTable pendingReviewEvents =
      $PendingReviewEventsTable(this);
  late final $PendingAppEventsTable pendingAppEvents =
      $PendingAppEventsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $CachedChaptersTable cachedChapters = $CachedChaptersTable(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        specialities,
        chapters,
        topics,
        qnas,
        images,
        imageBlobs,
        pendingReviewEvents,
        pendingAppEvents,
        bookmarks,
        cachedChapters,
        localSettings
      ];
}

typedef $$SpecialitiesTableCreateCompanionBuilder = SpecialitiesCompanion
    Function({
  required String id,
  required String name,
  required String examType,
  required String slug,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$SpecialitiesTableUpdateCompanionBuilder = SpecialitiesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> examType,
  Value<String> slug,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$SpecialitiesTableFilterComposer
    extends Composer<_$AppDatabase, $SpecialitiesTable> {
  $$SpecialitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get examType => $composableBuilder(
      column: $table.examType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$SpecialitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $SpecialitiesTable> {
  $$SpecialitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get examType => $composableBuilder(
      column: $table.examType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$SpecialitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpecialitiesTable> {
  $$SpecialitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get examType =>
      $composableBuilder(column: $table.examType, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$SpecialitiesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SpecialitiesTable,
    Speciality,
    $$SpecialitiesTableFilterComposer,
    $$SpecialitiesTableOrderingComposer,
    $$SpecialitiesTableAnnotationComposer,
    $$SpecialitiesTableCreateCompanionBuilder,
    $$SpecialitiesTableUpdateCompanionBuilder,
    (Speciality, BaseReferences<_$AppDatabase, $SpecialitiesTable, Speciality>),
    Speciality,
    PrefetchHooks Function()> {
  $$SpecialitiesTableTableManager(_$AppDatabase db, $SpecialitiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpecialitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpecialitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpecialitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> examType = const Value.absent(),
            Value<String> slug = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SpecialitiesCompanion(
            id: id,
            name: name,
            examType: examType,
            slug: slug,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String examType,
            required String slug,
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SpecialitiesCompanion.insert(
            id: id,
            name: name,
            examType: examType,
            slug: slug,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SpecialitiesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SpecialitiesTable,
    Speciality,
    $$SpecialitiesTableFilterComposer,
    $$SpecialitiesTableOrderingComposer,
    $$SpecialitiesTableAnnotationComposer,
    $$SpecialitiesTableCreateCompanionBuilder,
    $$SpecialitiesTableUpdateCompanionBuilder,
    (Speciality, BaseReferences<_$AppDatabase, $SpecialitiesTable, Speciality>),
    Speciality,
    PrefetchHooks Function()>;
typedef $$ChaptersTableCreateCompanionBuilder = ChaptersCompanion Function({
  required String id,
  required String specialityId,
  required String title,
  required String slug,
  Value<int> sortOrder,
  Value<int> examWeight,
  Value<int> contentVersion,
  Value<int> rowid,
});
typedef $$ChaptersTableUpdateCompanionBuilder = ChaptersCompanion Function({
  Value<String> id,
  Value<String> specialityId,
  Value<String> title,
  Value<String> slug,
  Value<int> sortOrder,
  Value<int> examWeight,
  Value<int> contentVersion,
  Value<int> rowid,
});

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get specialityId => $composableBuilder(
      column: $table.specialityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get examWeight => $composableBuilder(
      column: $table.examWeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contentVersion => $composableBuilder(
      column: $table.contentVersion,
      builder: (column) => ColumnFilters(column));
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get specialityId => $composableBuilder(
      column: $table.specialityId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get examWeight => $composableBuilder(
      column: $table.examWeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contentVersion => $composableBuilder(
      column: $table.contentVersion,
      builder: (column) => ColumnOrderings(column));
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get specialityId => $composableBuilder(
      column: $table.specialityId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get examWeight => $composableBuilder(
      column: $table.examWeight, builder: (column) => column);

  GeneratedColumn<int> get contentVersion => $composableBuilder(
      column: $table.contentVersion, builder: (column) => column);
}

class $$ChaptersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChaptersTable,
    Chapter,
    $$ChaptersTableFilterComposer,
    $$ChaptersTableOrderingComposer,
    $$ChaptersTableAnnotationComposer,
    $$ChaptersTableCreateCompanionBuilder,
    $$ChaptersTableUpdateCompanionBuilder,
    (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
    Chapter,
    PrefetchHooks Function()> {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> specialityId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> slug = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> examWeight = const Value.absent(),
            Value<int> contentVersion = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChaptersCompanion(
            id: id,
            specialityId: specialityId,
            title: title,
            slug: slug,
            sortOrder: sortOrder,
            examWeight: examWeight,
            contentVersion: contentVersion,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String specialityId,
            required String title,
            required String slug,
            Value<int> sortOrder = const Value.absent(),
            Value<int> examWeight = const Value.absent(),
            Value<int> contentVersion = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChaptersCompanion.insert(
            id: id,
            specialityId: specialityId,
            title: title,
            slug: slug,
            sortOrder: sortOrder,
            examWeight: examWeight,
            contentVersion: contentVersion,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChaptersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChaptersTable,
    Chapter,
    $$ChaptersTableFilterComposer,
    $$ChaptersTableOrderingComposer,
    $$ChaptersTableAnnotationComposer,
    $$ChaptersTableCreateCompanionBuilder,
    $$ChaptersTableUpdateCompanionBuilder,
    (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
    Chapter,
    PrefetchHooks Function()>;
typedef $$TopicsTableCreateCompanionBuilder = TopicsCompanion Function({
  required String id,
  required String chapterId,
  required String title,
  required String slug,
  Value<String?> examTheme,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$TopicsTableUpdateCompanionBuilder = TopicsCompanion Function({
  Value<String> id,
  Value<String> chapterId,
  Value<String> title,
  Value<String> slug,
  Value<String?> examTheme,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$TopicsTableFilterComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get examTheme => $composableBuilder(
      column: $table.examTheme, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$TopicsTableOrderingComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slug => $composableBuilder(
      column: $table.slug, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get examTheme => $composableBuilder(
      column: $table.examTheme, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$TopicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get examTheme =>
      $composableBuilder(column: $table.examTheme, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$TopicsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TopicsTable,
    Topic,
    $$TopicsTableFilterComposer,
    $$TopicsTableOrderingComposer,
    $$TopicsTableAnnotationComposer,
    $$TopicsTableCreateCompanionBuilder,
    $$TopicsTableUpdateCompanionBuilder,
    (Topic, BaseReferences<_$AppDatabase, $TopicsTable, Topic>),
    Topic,
    PrefetchHooks Function()> {
  $$TopicsTableTableManager(_$AppDatabase db, $TopicsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> chapterId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> slug = const Value.absent(),
            Value<String?> examTheme = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TopicsCompanion(
            id: id,
            chapterId: chapterId,
            title: title,
            slug: slug,
            examTheme: examTheme,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String chapterId,
            required String title,
            required String slug,
            Value<String?> examTheme = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TopicsCompanion.insert(
            id: id,
            chapterId: chapterId,
            title: title,
            slug: slug,
            examTheme: examTheme,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TopicsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TopicsTable,
    Topic,
    $$TopicsTableFilterComposer,
    $$TopicsTableOrderingComposer,
    $$TopicsTableAnnotationComposer,
    $$TopicsTableCreateCompanionBuilder,
    $$TopicsTableUpdateCompanionBuilder,
    (Topic, BaseReferences<_$AppDatabase, $TopicsTable, Topic>),
    Topic,
    PrefetchHooks Function()>;
typedef $$QnasTableCreateCompanionBuilder = QnasCompanion Function({
  required String id,
  required String topicId,
  required String question,
  Value<String?> years,
  Value<int?> marks,
  required String earnsMarks,
  required String sections,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$QnasTableUpdateCompanionBuilder = QnasCompanion Function({
  Value<String> id,
  Value<String> topicId,
  Value<String> question,
  Value<String?> years,
  Value<int?> marks,
  Value<String> earnsMarks,
  Value<String> sections,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$QnasTableFilterComposer extends Composer<_$AppDatabase, $QnasTable> {
  $$QnasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get topicId => $composableBuilder(
      column: $table.topicId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get question => $composableBuilder(
      column: $table.question, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get years => $composableBuilder(
      column: $table.years, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get marks => $composableBuilder(
      column: $table.marks, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get earnsMarks => $composableBuilder(
      column: $table.earnsMarks, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sections => $composableBuilder(
      column: $table.sections, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$QnasTableOrderingComposer extends Composer<_$AppDatabase, $QnasTable> {
  $$QnasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get topicId => $composableBuilder(
      column: $table.topicId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get question => $composableBuilder(
      column: $table.question, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get years => $composableBuilder(
      column: $table.years, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get marks => $composableBuilder(
      column: $table.marks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get earnsMarks => $composableBuilder(
      column: $table.earnsMarks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sections => $composableBuilder(
      column: $table.sections, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$QnasTableAnnotationComposer
    extends Composer<_$AppDatabase, $QnasTable> {
  $$QnasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get years =>
      $composableBuilder(column: $table.years, builder: (column) => column);

  GeneratedColumn<int> get marks =>
      $composableBuilder(column: $table.marks, builder: (column) => column);

  GeneratedColumn<String> get earnsMarks => $composableBuilder(
      column: $table.earnsMarks, builder: (column) => column);

  GeneratedColumn<String> get sections =>
      $composableBuilder(column: $table.sections, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$QnasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QnasTable,
    Qna,
    $$QnasTableFilterComposer,
    $$QnasTableOrderingComposer,
    $$QnasTableAnnotationComposer,
    $$QnasTableCreateCompanionBuilder,
    $$QnasTableUpdateCompanionBuilder,
    (Qna, BaseReferences<_$AppDatabase, $QnasTable, Qna>),
    Qna,
    PrefetchHooks Function()> {
  $$QnasTableTableManager(_$AppDatabase db, $QnasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QnasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QnasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QnasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> topicId = const Value.absent(),
            Value<String> question = const Value.absent(),
            Value<String?> years = const Value.absent(),
            Value<int?> marks = const Value.absent(),
            Value<String> earnsMarks = const Value.absent(),
            Value<String> sections = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QnasCompanion(
            id: id,
            topicId: topicId,
            question: question,
            years: years,
            marks: marks,
            earnsMarks: earnsMarks,
            sections: sections,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String topicId,
            required String question,
            Value<String?> years = const Value.absent(),
            Value<int?> marks = const Value.absent(),
            required String earnsMarks,
            required String sections,
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QnasCompanion.insert(
            id: id,
            topicId: topicId,
            question: question,
            years: years,
            marks: marks,
            earnsMarks: earnsMarks,
            sections: sections,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QnasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QnasTable,
    Qna,
    $$QnasTableFilterComposer,
    $$QnasTableOrderingComposer,
    $$QnasTableAnnotationComposer,
    $$QnasTableCreateCompanionBuilder,
    $$QnasTableUpdateCompanionBuilder,
    (Qna, BaseReferences<_$AppDatabase, $QnasTable, Qna>),
    Qna,
    PrefetchHooks Function()>;
typedef $$ImagesTableCreateCompanionBuilder = ImagesCompanion Function({
  required String id,
  required String qnaId,
  required String caption,
  required String contentDescription,
  required int byteSize,
  required String sha256,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$ImagesTableUpdateCompanionBuilder = ImagesCompanion Function({
  Value<String> id,
  Value<String> qnaId,
  Value<String> caption,
  Value<String> contentDescription,
  Value<int> byteSize,
  Value<String> sha256,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$ImagesTableFilterComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get qnaId => $composableBuilder(
      column: $table.qnaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get caption => $composableBuilder(
      column: $table.caption, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentDescription => $composableBuilder(
      column: $table.contentDescription,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get byteSize => $composableBuilder(
      column: $table.byteSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$ImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get qnaId => $composableBuilder(
      column: $table.qnaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get caption => $composableBuilder(
      column: $table.caption, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentDescription => $composableBuilder(
      column: $table.contentDescription,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get byteSize => $composableBuilder(
      column: $table.byteSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$ImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImagesTable> {
  $$ImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get qnaId =>
      $composableBuilder(column: $table.qnaId, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get contentDescription => $composableBuilder(
      column: $table.contentDescription, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ImagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ImagesTable,
    Image,
    $$ImagesTableFilterComposer,
    $$ImagesTableOrderingComposer,
    $$ImagesTableAnnotationComposer,
    $$ImagesTableCreateCompanionBuilder,
    $$ImagesTableUpdateCompanionBuilder,
    (Image, BaseReferences<_$AppDatabase, $ImagesTable, Image>),
    Image,
    PrefetchHooks Function()> {
  $$ImagesTableTableManager(_$AppDatabase db, $ImagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> qnaId = const Value.absent(),
            Value<String> caption = const Value.absent(),
            Value<String> contentDescription = const Value.absent(),
            Value<int> byteSize = const Value.absent(),
            Value<String> sha256 = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ImagesCompanion(
            id: id,
            qnaId: qnaId,
            caption: caption,
            contentDescription: contentDescription,
            byteSize: byteSize,
            sha256: sha256,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String qnaId,
            required String caption,
            required String contentDescription,
            required int byteSize,
            required String sha256,
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ImagesCompanion.insert(
            id: id,
            qnaId: qnaId,
            caption: caption,
            contentDescription: contentDescription,
            byteSize: byteSize,
            sha256: sha256,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ImagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ImagesTable,
    Image,
    $$ImagesTableFilterComposer,
    $$ImagesTableOrderingComposer,
    $$ImagesTableAnnotationComposer,
    $$ImagesTableCreateCompanionBuilder,
    $$ImagesTableUpdateCompanionBuilder,
    (Image, BaseReferences<_$AppDatabase, $ImagesTable, Image>),
    Image,
    PrefetchHooks Function()>;
typedef $$ImageBlobsTableCreateCompanionBuilder = ImageBlobsCompanion Function({
  required String imageId,
  required Uint8List bytes,
  required String sha256,
  Value<int> rowid,
});
typedef $$ImageBlobsTableUpdateCompanionBuilder = ImageBlobsCompanion Function({
  Value<String> imageId,
  Value<Uint8List> bytes,
  Value<String> sha256,
  Value<int> rowid,
});

class $$ImageBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $ImageBlobsTable> {
  $$ImageBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get imageId => $composableBuilder(
      column: $table.imageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnFilters(column));
}

class $$ImageBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageBlobsTable> {
  $$ImageBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get imageId => $composableBuilder(
      column: $table.imageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
      column: $table.bytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnOrderings(column));
}

class $$ImageBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageBlobsTable> {
  $$ImageBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get imageId =>
      $composableBuilder(column: $table.imageId, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);
}

class $$ImageBlobsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ImageBlobsTable,
    ImageBlob,
    $$ImageBlobsTableFilterComposer,
    $$ImageBlobsTableOrderingComposer,
    $$ImageBlobsTableAnnotationComposer,
    $$ImageBlobsTableCreateCompanionBuilder,
    $$ImageBlobsTableUpdateCompanionBuilder,
    (ImageBlob, BaseReferences<_$AppDatabase, $ImageBlobsTable, ImageBlob>),
    ImageBlob,
    PrefetchHooks Function()> {
  $$ImageBlobsTableTableManager(_$AppDatabase db, $ImageBlobsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> imageId = const Value.absent(),
            Value<Uint8List> bytes = const Value.absent(),
            Value<String> sha256 = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ImageBlobsCompanion(
            imageId: imageId,
            bytes: bytes,
            sha256: sha256,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String imageId,
            required Uint8List bytes,
            required String sha256,
            Value<int> rowid = const Value.absent(),
          }) =>
              ImageBlobsCompanion.insert(
            imageId: imageId,
            bytes: bytes,
            sha256: sha256,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ImageBlobsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ImageBlobsTable,
    ImageBlob,
    $$ImageBlobsTableFilterComposer,
    $$ImageBlobsTableOrderingComposer,
    $$ImageBlobsTableAnnotationComposer,
    $$ImageBlobsTableCreateCompanionBuilder,
    $$ImageBlobsTableUpdateCompanionBuilder,
    (ImageBlob, BaseReferences<_$AppDatabase, $ImageBlobsTable, ImageBlob>),
    ImageBlob,
    PrefetchHooks Function()>;
typedef $$PendingReviewEventsTableCreateCompanionBuilder
    = PendingReviewEventsCompanion Function({
  required String id,
  required String contentId,
  required String rating,
  required DateTime shownAt,
  required DateTime revealedAt,
  required DateTime ratedAt,
  required String localDay,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$PendingReviewEventsTableUpdateCompanionBuilder
    = PendingReviewEventsCompanion Function({
  Value<String> id,
  Value<String> contentId,
  Value<String> rating,
  Value<DateTime> shownAt,
  Value<DateTime> revealedAt,
  Value<DateTime> ratedAt,
  Value<String> localDay,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

class $$PendingReviewEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingReviewEventsTable> {
  $$PendingReviewEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get shownAt => $composableBuilder(
      column: $table.shownAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get revealedAt => $composableBuilder(
      column: $table.revealedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get ratedAt => $composableBuilder(
      column: $table.ratedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localDay => $composableBuilder(
      column: $table.localDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$PendingReviewEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingReviewEventsTable> {
  $$PendingReviewEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get shownAt => $composableBuilder(
      column: $table.shownAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get revealedAt => $composableBuilder(
      column: $table.revealedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get ratedAt => $composableBuilder(
      column: $table.ratedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localDay => $composableBuilder(
      column: $table.localDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingReviewEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingReviewEventsTable> {
  $$PendingReviewEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get shownAt =>
      $composableBuilder(column: $table.shownAt, builder: (column) => column);

  GeneratedColumn<DateTime> get revealedAt => $composableBuilder(
      column: $table.revealedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get ratedAt =>
      $composableBuilder(column: $table.ratedAt, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$PendingReviewEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingReviewEventsTable,
    PendingReviewEvent,
    $$PendingReviewEventsTableFilterComposer,
    $$PendingReviewEventsTableOrderingComposer,
    $$PendingReviewEventsTableAnnotationComposer,
    $$PendingReviewEventsTableCreateCompanionBuilder,
    $$PendingReviewEventsTableUpdateCompanionBuilder,
    (
      PendingReviewEvent,
      BaseReferences<_$AppDatabase, $PendingReviewEventsTable,
          PendingReviewEvent>
    ),
    PendingReviewEvent,
    PrefetchHooks Function()> {
  $$PendingReviewEventsTableTableManager(
      _$AppDatabase db, $PendingReviewEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingReviewEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingReviewEventsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingReviewEventsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> contentId = const Value.absent(),
            Value<String> rating = const Value.absent(),
            Value<DateTime> shownAt = const Value.absent(),
            Value<DateTime> revealedAt = const Value.absent(),
            Value<DateTime> ratedAt = const Value.absent(),
            Value<String> localDay = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingReviewEventsCompanion(
            id: id,
            contentId: contentId,
            rating: rating,
            shownAt: shownAt,
            revealedAt: revealedAt,
            ratedAt: ratedAt,
            localDay: localDay,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String contentId,
            required String rating,
            required DateTime shownAt,
            required DateTime revealedAt,
            required DateTime ratedAt,
            required String localDay,
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingReviewEventsCompanion.insert(
            id: id,
            contentId: contentId,
            rating: rating,
            shownAt: shownAt,
            revealedAt: revealedAt,
            ratedAt: ratedAt,
            localDay: localDay,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingReviewEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingReviewEventsTable,
    PendingReviewEvent,
    $$PendingReviewEventsTableFilterComposer,
    $$PendingReviewEventsTableOrderingComposer,
    $$PendingReviewEventsTableAnnotationComposer,
    $$PendingReviewEventsTableCreateCompanionBuilder,
    $$PendingReviewEventsTableUpdateCompanionBuilder,
    (
      PendingReviewEvent,
      BaseReferences<_$AppDatabase, $PendingReviewEventsTable,
          PendingReviewEvent>
    ),
    PendingReviewEvent,
    PrefetchHooks Function()>;
typedef $$PendingAppEventsTableCreateCompanionBuilder
    = PendingAppEventsCompanion Function({
  required String id,
  required String eventType,
  Value<String?> contentId,
  Value<int?> hiddenMs,
  required DateTime occurredAt,
  required String localDay,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$PendingAppEventsTableUpdateCompanionBuilder
    = PendingAppEventsCompanion Function({
  Value<String> id,
  Value<String> eventType,
  Value<String?> contentId,
  Value<int?> hiddenMs,
  Value<DateTime> occurredAt,
  Value<String> localDay,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

class $$PendingAppEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingAppEventsTable> {
  $$PendingAppEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hiddenMs => $composableBuilder(
      column: $table.hiddenMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localDay => $composableBuilder(
      column: $table.localDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$PendingAppEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingAppEventsTable> {
  $$PendingAppEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hiddenMs => $composableBuilder(
      column: $table.hiddenMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localDay => $composableBuilder(
      column: $table.localDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingAppEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingAppEventsTable> {
  $$PendingAppEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<int> get hiddenMs =>
      $composableBuilder(column: $table.hiddenMs, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$PendingAppEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingAppEventsTable,
    PendingAppEvent,
    $$PendingAppEventsTableFilterComposer,
    $$PendingAppEventsTableOrderingComposer,
    $$PendingAppEventsTableAnnotationComposer,
    $$PendingAppEventsTableCreateCompanionBuilder,
    $$PendingAppEventsTableUpdateCompanionBuilder,
    (
      PendingAppEvent,
      BaseReferences<_$AppDatabase, $PendingAppEventsTable, PendingAppEvent>
    ),
    PendingAppEvent,
    PrefetchHooks Function()> {
  $$PendingAppEventsTableTableManager(
      _$AppDatabase db, $PendingAppEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingAppEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingAppEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingAppEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String?> contentId = const Value.absent(),
            Value<int?> hiddenMs = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<String> localDay = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingAppEventsCompanion(
            id: id,
            eventType: eventType,
            contentId: contentId,
            hiddenMs: hiddenMs,
            occurredAt: occurredAt,
            localDay: localDay,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String eventType,
            Value<String?> contentId = const Value.absent(),
            Value<int?> hiddenMs = const Value.absent(),
            required DateTime occurredAt,
            required String localDay,
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingAppEventsCompanion.insert(
            id: id,
            eventType: eventType,
            contentId: contentId,
            hiddenMs: hiddenMs,
            occurredAt: occurredAt,
            localDay: localDay,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingAppEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingAppEventsTable,
    PendingAppEvent,
    $$PendingAppEventsTableFilterComposer,
    $$PendingAppEventsTableOrderingComposer,
    $$PendingAppEventsTableAnnotationComposer,
    $$PendingAppEventsTableCreateCompanionBuilder,
    $$PendingAppEventsTableUpdateCompanionBuilder,
    (
      PendingAppEvent,
      BaseReferences<_$AppDatabase, $PendingAppEventsTable, PendingAppEvent>
    ),
    PendingAppEvent,
    PrefetchHooks Function()>;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  required String contentId,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<int> rowid,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<String> contentId,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<int> rowid,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$BookmarksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BookmarksTable,
    Bookmark,
    $$BookmarksTableFilterComposer,
    $$BookmarksTableOrderingComposer,
    $$BookmarksTableAnnotationComposer,
    $$BookmarksTableCreateCompanionBuilder,
    $$BookmarksTableUpdateCompanionBuilder,
    (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
    Bookmark,
    PrefetchHooks Function()> {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> contentId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion(
            contentId: contentId,
            updatedAt: updatedAt,
            deleted: deleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String contentId,
            required DateTime updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BookmarksCompanion.insert(
            contentId: contentId,
            updatedAt: updatedAt,
            deleted: deleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BookmarksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BookmarksTable,
    Bookmark,
    $$BookmarksTableFilterComposer,
    $$BookmarksTableOrderingComposer,
    $$BookmarksTableAnnotationComposer,
    $$BookmarksTableCreateCompanionBuilder,
    $$BookmarksTableUpdateCompanionBuilder,
    (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
    Bookmark,
    PrefetchHooks Function()>;
typedef $$CachedChaptersTableCreateCompanionBuilder = CachedChaptersCompanion
    Function({
  required String chapterId,
  required int contentVersion,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$CachedChaptersTableUpdateCompanionBuilder = CachedChaptersCompanion
    Function({
  Value<String> chapterId,
  Value<int> contentVersion,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$CachedChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedChaptersTable> {
  $$CachedChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contentVersion => $composableBuilder(
      column: $table.contentVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedChaptersTable> {
  $$CachedChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chapterId => $composableBuilder(
      column: $table.chapterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contentVersion => $composableBuilder(
      column: $table.contentVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedChaptersTable> {
  $$CachedChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get contentVersion => $composableBuilder(
      column: $table.contentVersion, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedChaptersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedChaptersTable,
    CachedChapter,
    $$CachedChaptersTableFilterComposer,
    $$CachedChaptersTableOrderingComposer,
    $$CachedChaptersTableAnnotationComposer,
    $$CachedChaptersTableCreateCompanionBuilder,
    $$CachedChaptersTableUpdateCompanionBuilder,
    (
      CachedChapter,
      BaseReferences<_$AppDatabase, $CachedChaptersTable, CachedChapter>
    ),
    CachedChapter,
    PrefetchHooks Function()> {
  $$CachedChaptersTableTableManager(
      _$AppDatabase db, $CachedChaptersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> chapterId = const Value.absent(),
            Value<int> contentVersion = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedChaptersCompanion(
            chapterId: chapterId,
            contentVersion: contentVersion,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String chapterId,
            required int contentVersion,
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedChaptersCompanion.insert(
            chapterId: chapterId,
            contentVersion: contentVersion,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedChaptersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedChaptersTable,
    CachedChapter,
    $$CachedChaptersTableFilterComposer,
    $$CachedChaptersTableOrderingComposer,
    $$CachedChaptersTableAnnotationComposer,
    $$CachedChaptersTableCreateCompanionBuilder,
    $$CachedChaptersTableUpdateCompanionBuilder,
    (
      CachedChapter,
      BaseReferences<_$AppDatabase, $CachedChaptersTable, CachedChapter>
    ),
    CachedChapter,
    PrefetchHooks Function()>;
typedef $$LocalSettingsTableCreateCompanionBuilder = LocalSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$LocalSettingsTableUpdateCompanionBuilder = LocalSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$LocalSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$LocalSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$LocalSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalSettingsTable,
    LocalSetting,
    $$LocalSettingsTableFilterComposer,
    $$LocalSettingsTableOrderingComposer,
    $$LocalSettingsTableAnnotationComposer,
    $$LocalSettingsTableCreateCompanionBuilder,
    $$LocalSettingsTableUpdateCompanionBuilder,
    (
      LocalSetting,
      BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>
    ),
    LocalSetting,
    PrefetchHooks Function()> {
  $$LocalSettingsTableTableManager(_$AppDatabase db, $LocalSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalSettingsTable,
    LocalSetting,
    $$LocalSettingsTableFilterComposer,
    $$LocalSettingsTableOrderingComposer,
    $$LocalSettingsTableAnnotationComposer,
    $$LocalSettingsTableCreateCompanionBuilder,
    $$LocalSettingsTableUpdateCompanionBuilder,
    (
      LocalSetting,
      BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>
    ),
    LocalSetting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SpecialitiesTableTableManager get specialities =>
      $$SpecialitiesTableTableManager(_db, _db.specialities);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db, _db.topics);
  $$QnasTableTableManager get qnas => $$QnasTableTableManager(_db, _db.qnas);
  $$ImagesTableTableManager get images =>
      $$ImagesTableTableManager(_db, _db.images);
  $$ImageBlobsTableTableManager get imageBlobs =>
      $$ImageBlobsTableTableManager(_db, _db.imageBlobs);
  $$PendingReviewEventsTableTableManager get pendingReviewEvents =>
      $$PendingReviewEventsTableTableManager(_db, _db.pendingReviewEvents);
  $$PendingAppEventsTableTableManager get pendingAppEvents =>
      $$PendingAppEventsTableTableManager(_db, _db.pendingAppEvents);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$CachedChaptersTableTableManager get cachedChapters =>
      $$CachedChaptersTableTableManager(_db, _db.cachedChapters);
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
}
