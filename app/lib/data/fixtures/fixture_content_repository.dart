import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models.dart';
import '../repos/content_repository.dart';

/// Fixture-backed ContentRepository. The 61 specialities mirror
/// sql/0002_seed_specialities.sql verbatim (name, examType, slug, sortOrder);
/// only Anaesthesiology has content (TD3: Anaesthesia-only free-beta data,
/// the other 60 exercise the empty-track state, live-by-design). The
/// Anaesthesiology row uses the fixture's own local ULID (from
/// chapter_airway.json) so its speciality_id resolves the chapter tree; the
/// real production anchor (01JZSP3C00DNB0000000000001) never appears here.
class FixtureContentRepository implements ContentRepository {
  FixtureContentRepository({this.failChapterFetch = false});

  /// Set true in widget tests to exercise the "Couldn't load this - retry" state.
  bool failChapterFetch;

  Map<String, dynamic>? _doc;
  final Set<String> _cached = {};

  // cache: false - the global rootBundle string cache returns a Future bound
  // to the first widget test's FakeAsync zone, which hangs a later test in the
  // same isolate that awaits it; _doc already memoizes for the real app.
  Future<Map<String, dynamic>> _load() async => _doc ??= json
      .decode(await rootBundle
          .loadString('assets/fixtures/chapter_airway.json', cache: false))
      as Map<String, dynamic>;

  /// (name, examType, slug, sortOrder) - verbatim from
  /// sql/0002_seed_specialities.sql, all 61 DNB/DrNB tracks.
  static const _seedTracks = <(String, String, String, int)>[
    ('Anaesthesiology', 'DNB', 'anaesthesiology', 1),
    ('Anatomy', 'DNB', 'anatomy', 2),
    ('Biochemistry', 'DNB', 'biochemistry', 3),
    ('Community Medicine', 'DNB', 'community-medicine', 4),
    ('Dermatology, Venereology and Leprosy', 'DNB', 'dermatology-venereology-and-leprosy', 5),
    ('Emergency Medicine', 'DNB', 'emergency-medicine', 6),
    ('Family Medicine', 'DNB', 'family-medicine', 7),
    ('Forensic Medicine', 'DNB', 'forensic-medicine', 8),
    ('General Medicine', 'DNB', 'general-medicine', 9),
    ('General Surgery', 'DNB', 'general-surgery', 10),
    ('Hospital Administration', 'DNB', 'hospital-administration', 11),
    ('Immunohematology and Blood Transfusion', 'DNB', 'immunohematology-and-blood-transfusion', 12),
    ('Maternal and Child Health', 'DNB', 'maternal-and-child-health', 13),
    ('Microbiology', 'DNB', 'microbiology', 14),
    ('Nuclear Medicine', 'DNB', 'nuclear-medicine', 15),
    ('Obstetrics and Gynaecology', 'DNB', 'obstetrics-and-gynaecology', 16),
    ('Ophthalmology', 'DNB', 'ophthalmology', 17),
    ('Orthopaedics', 'DNB', 'orthopaedics', 18),
    ('Otorhinolaryngology (ENT)', 'DNB', 'otorhinolaryngology-ent', 19),
    ('Paediatrics', 'DNB', 'paediatrics', 20),
    ('Palliative Medicine', 'DNB', 'palliative-medicine', 21),
    ('Pathology', 'DNB', 'pathology', 22),
    ('Pharmacology', 'DNB', 'pharmacology', 23),
    ('Physical Medicine and Rehabilitation', 'DNB', 'physical-medicine-and-rehabilitation', 24),
    ('Physiology', 'DNB', 'physiology', 25),
    ('Psychiatry', 'DNB', 'psychiatry', 26),
    ('Radiation Oncology', 'DNB', 'radiation-oncology', 27),
    ('Radio Diagnosis', 'DNB', 'radio-diagnosis', 28),
    ('Respiratory Medicine', 'DNB', 'respiratory-medicine', 29),
    ('Trauma and Acute Care Surgery', 'DNB', 'trauma-and-acute-care-surgery', 30),
    ('Cardiac Anaesthesia', 'DrNB', 'cardiac-anaesthesia', 31),
    ('Cardiology', 'DrNB', 'cardiology', 32),
    ('Cardiovascular & Thoracic Surgery', 'DrNB', 'cardiovascular-and-thoracic-surgery', 33),
    ('Clinical Haematology', 'DrNB', 'clinical-haematology', 34),
    ('Clinical Immunology & Rheumatology', 'DrNB', 'clinical-immunology-and-rheumatology', 35),
    ('Critical Care Medicine', 'DrNB', 'critical-care-medicine', 36),
    ('Endocrinology', 'DrNB', 'endocrinology', 37),
    ('Gynaecological Oncology', 'DrNB', 'gynaecological-oncology', 38),
    ('Head and Neck Oncology', 'DrNB', 'head-and-neck-oncology', 39),
    ('Infectious Disease', 'DrNB', 'infectious-disease', 40),
    ('Interventional Radiology', 'DrNB', 'interventional-radiology', 41),
    ('Medical Gastroenterology', 'DrNB', 'medical-gastroenterology', 42),
    ('Medical Genetics', 'DrNB', 'medical-genetics', 43),
    ('Medical Oncology', 'DrNB', 'medical-oncology', 44),
    ('Neonatology', 'DrNB', 'neonatology', 45),
    ('Nephrology', 'DrNB', 'nephrology', 46),
    ('Neuro Anaesthesia', 'DrNB', 'neuro-anaesthesia', 47),
    ('Neurology', 'DrNB', 'neurology', 48),
    ('Neurosurgery', 'DrNB', 'neurosurgery', 49),
    ('Paediatric Cardiology', 'DrNB', 'paediatric-cardiology', 50),
    ('Paediatric Critical Care', 'DrNB', 'paediatric-critical-care', 51),
    ('Paediatric Haemato-Oncology', 'DrNB', 'paediatric-haemato-oncology', 52),
    ('Paediatric Neurology', 'DrNB', 'paediatric-neurology', 53),
    ('Paediatric Surgery', 'DrNB', 'paediatric-surgery', 54),
    ('Plastic & Reconstructive Surgery', 'DrNB', 'plastic-and-reconstructive-surgery', 55),
    ('Pulmonary Medicine', 'DrNB', 'pulmonary-medicine', 56),
    ('Surgical Gastroenterology', 'DrNB', 'surgical-gastroenterology', 57),
    ('Surgical Oncology', 'DrNB', 'surgical-oncology', 58),
    ('Thoracic Surgery', 'DrNB', 'thoracic-surgery', 59),
    ('Urology', 'DrNB', 'urology', 60),
    ('Vascular Surgery', 'DrNB', 'vascular-surgery', 61),
  ];

  @override
  Future<List<SpecialityRow>> specialities() async {
    final doc = await _load();
    final anaes = doc['speciality'] as Map<String, dynamic>;
    return [
      for (final (name, examType, slug, sortOrder) in _seedTracks)
        SpecialityRow(
          id: name == 'Anaesthesiology'
              ? anaes['id'] as String
              : '01J0SPECFIXTURE${sortOrder.toString().padLeft(10, '0')}',
          name: name,
          examType: examType,
          slug: slug,
          sortOrder: sortOrder,
          hasContent: name == 'Anaesthesiology',
        ),
    ];
  }

  @override
  Future<List<ChapterRow>> chapters(String specialityId) async {
    final doc = await _load();
    if (specialityId != (doc['speciality'] as Map)['id']) return const [];
    final qnas = (doc['qnas'] as List).cast<Map<String, dynamic>>();
    return [
      for (final c in (doc['chapters'] as List).cast<Map<String, dynamic>>())
        ChapterRow(
          id: c['id'] as String,
          specialityId: c['speciality_id'] as String,
          title: c['title'] as String,
          slug: c['slug'] as String,
          sortOrder: c['sort_order'] as int,
          examWeight: c['exam_weight'] as int,
          contentVersion: c['content_version'] as int,
          qnaCount: qnas.where((q) => q['chapter_id'] == c['id']).length,
        ),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> ensureChapterCached(String chapterId) async {
    if (failChapterFetch) throw ContentFetchException(chapterId);
    _cached.add(chapterId);
  }

  QnaRow _qnaFromJson(Map<String, dynamic> q) => QnaRow(
        id: q['id'] as String, chapterId: q['chapter_id'] as String,
        question: q['question'] as String, years: q['years'] as String?,
        marks: q['marks'] as int?,
        earnsMarks: [
          for (final e in (q['earns_marks'] as List).cast<Map<String, dynamic>>())
            EarnRow(label: e['label'] as String, sectionKey: e['section_key'] as String)
        ],
        sections: [
          for (final s in (q['sections'] as List).cast<Map<String, dynamic>>())
            AnswerSection(key: s['key'] as String, heading: s['heading'] as String,
                bodyMd: s['body_md'] as String, marks: s['marks'] as int?)
        ],
        sortOrder: q['sort_order'] as int,
        images: [
          for (final i in (q['images'] as List).cast<Map<String, dynamic>>())
            ImageRow(id: i['id'] as String, caption: i['caption'] as String,
                contentDescription: i['content_description'] as String,
                byteSize: i['byte_size'] as int, sha256: i['sha256'] as String,
                sortOrder: i['sort_order'] as int)
        ],
      );

  @override
  Future<List<QnaRow>> qnas(String chapterId) async {
    final doc = await _load();
    return [
      for (final q in (doc['qnas'] as List).cast<Map<String, dynamic>>())
        if (q['chapter_id'] == chapterId) _qnaFromJson(q),
    ]..sort((a, b) => a.sortOrder != b.sortOrder
        ? a.sortOrder.compareTo(b.sortOrder)
        : a.id.compareTo(b.id));
  }

  @override
  Future<QnaRow?> qna(String qnaId) async {
    final doc = await _load();
    for (final q in (doc['qnas'] as List).cast<Map<String, dynamic>>()) {
      if (q['id'] == qnaId) return _qnaFromJson(q);
    }
    return null;
  }

  @override
  Future<Uint8List> imageBytes(String imageId) async =>
      (await rootBundle.load('assets/fixtures/images/fig_tap_block.webp'))
          .buffer
          .asUint8List();
}
