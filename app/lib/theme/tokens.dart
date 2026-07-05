import 'package:flutter/material.dart';

/// Transcribed from DESIGN.md token tables (Clinical Chart / Night Desk).
/// Semantic tokens only - never raw hex at call sites. Do not add values.
class DmColors {
  const DmColors({
    required this.paper,
    required this.elevated,
    required this.sunk,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.rule,
    required this.ruleStrong,
    required this.teal,
    required this.tealSoft,
    required this.tealInk,
    required this.amber,
    required this.amberSoft,
    required this.examRed,
    required this.ok,
    required this.navBg,
    required this.navRule,
  });

  final Color paper;
  final Color elevated;
  final Color sunk;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color rule;
  final Color ruleStrong;

  /// Fills and strokes ONLY. Teal used as text must be [tealInk] (color law 1).
  final Color teal;
  final Color tealSoft;

  /// Teal used as text (overlines, active nav, links).
  final Color tealInk;
  final Color amber;
  final Color amberSoft;
  final Color examRed;
  final Color ok;
  final Color navBg;
  final Color navRule;

  /// One red, one source (color law 5).
  Color get danger => examRed;
}

const dmLight = DmColors(
  paper: Color(0xFFF6F8FA),
  elevated: Color(0xFFFFFFFF),
  sunk: Color(0xFFEDF1F5),
  ink: Color(0xFF0E1626),
  ink2: Color(0xFF57657A),
  ink3: Color(0xFF5F6F84),
  rule: Color(0xFFE1E7EE),
  ruleStrong: Color(0xFFCFD8E2),
  teal: Color(0xFF087A72),
  tealSoft: Color(0x14087A72),
  tealInk: Color(0xFF0A6E67),
  amber: Color(0xFFA85B10),
  amberSoft: Color(0x12A85B10),
  examRed: Color(0xFFB4271F),
  ok: Color(0xFF1E7A46),
  navBg: Color(0xFFFBFCFD),
  navRule: Color(0xFFE4EAF0),
);

const dmDark = DmColors(
  paper: Color(0xFF19181A),
  elevated: Color(0xFF211F22),
  sunk: Color(0xFF141315),
  ink: Color(0xFFECE6DC),
  ink2: Color(0xFF9C9488),
  ink3: Color(0xFF908878),
  rule: Color(0xFF302D31),
  ruleStrong: Color(0xFF3E3A3F),
  teal: Color(0xFF3ED8C4),
  tealSoft: Color(0x183ED8C4),
  tealInk: Color(0xFF8CEBDD),
  amber: Color(0xFFF2B44C),
  amberSoft: Color(0x14F2B44C),
  examRed: Color(0xFFF08A82),
  ok: Color(0xFF5FCF8A),
  navBg: Color(0xFF141315),
  navRule: Color(0xFF2A282C),
);

/// The fixed 7-step type scale (DESIGN.md law - do not add sizes).
/// Variable fonts need explicit wght axes; fontWeight alone is not enough.
class DmType {
  static const String serif = 'SourceSerif4';
  static const String sans = 'Manrope';

  static const List<FontVariation> _serif400 = [FontVariation('wght', 400)];
  static const List<FontVariation> _serif600 = [FontVariation('wght', 600)];
  static const List<FontVariation> _sans500 = [FontVariation('wght', 500)];
  static const List<FontVariation> _sans600 = [FontVariation('wght', 600)];
  static const List<FontVariation> _sans700 = [FontVariation('wght', 700)];

  /// All changing numerals render tabular (DESIGN.md typography law).
  static const List<FontFeature> tabularNums = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(
      fontFamily: serif, fontSize: 28, fontWeight: FontWeight.w600, fontVariations: _serif600, height: 1.25);
  static const TextStyle title = TextStyle(
      fontFamily: serif, fontSize: 24, fontWeight: FontWeight.w600, fontVariations: _serif600, height: 1.4);
  static const TextStyle section = TextStyle(
      fontFamily: serif, fontSize: 19, fontWeight: FontWeight.w600, fontVariations: _serif600, height: 1.35);
  static const TextStyle body = TextStyle(
      fontFamily: serif, fontSize: 17, fontWeight: FontWeight.w400, fontVariations: _serif400, height: 1.55);
  static const TextStyle bodyUi = TextStyle(
      fontFamily: sans, fontSize: 15, fontWeight: FontWeight.w600, fontVariations: _sans600, height: 1.3);
  static const TextStyle meta = TextStyle(
      fontFamily: sans, fontSize: 12.5, fontWeight: FontWeight.w500, fontVariations: _sans500, height: 1.35);
  static const TextStyle label = TextStyle(
      fontFamily: sans,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      fontVariations: _sans700,
      letterSpacing: 11 * 0.14,
      height: 1.2);

  /// The one large-count slot (Home "This Week" numerals): Manrope 700 / 24.
  static const TextStyle statNumber = TextStyle(
      fontFamily: sans,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      fontVariations: _sans700,
      fontFeatures: tabularNums,
      height: 1.1);
}

/// 4px grid. Gutter is the single horizontal screen inset (18).
class DmSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double gutter = 18;
  static const double xl2 = 24;
  static const double xl3 = 32;
}

/// Radius only where containment is real: chips/inputs 8, buttons/plates 12.
class DmRadius {
  static const double sm = 8;
  static const double md = 12;
}

/// Motion budget (D20): reveal / rating-ack / queue-transition only.
class DmMotion {
  static const Duration micro = Duration(milliseconds: 80);
  static const Duration reveal = Duration(milliseconds: 200);
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration toastHold = Duration(milliseconds: 1500);
}

/// The examiner's-margin geometry (DESIGN.md Spacing section).
class DmReader {
  static const double examinerIndent = 26;
  static const double examinerRail = 19;
  static const double maxMeasure = 560;
}

class DmTheme extends ThemeExtension<DmTheme> {
  const DmTheme(this.colors);
  final DmColors colors;

  @override
  DmTheme copyWith({DmColors? colors}) => DmTheme(colors ?? this.colors);

  @override
  DmTheme lerp(DmTheme? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension DmContext on BuildContext {
  DmColors get dm => Theme.of(this).extension<DmTheme>()!.colors;
}
