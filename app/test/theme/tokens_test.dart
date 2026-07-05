import 'package:diplomate/theme/app_theme.dart';
import 'package:diplomate/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light tokens match DESIGN.md Clinical Chart table exactly', () {
    expect(dmLight.paper, const Color(0xFFF6F8FA));
    expect(dmLight.elevated, const Color(0xFFFFFFFF));
    expect(dmLight.sunk, const Color(0xFFEDF1F5));
    expect(dmLight.ink, const Color(0xFF0E1626));
    expect(dmLight.ink2, const Color(0xFF57657A));
    expect(dmLight.ink3, const Color(0xFF5F6F84));
    expect(dmLight.rule, const Color(0xFFE1E7EE));
    expect(dmLight.ruleStrong, const Color(0xFFCFD8E2));
    expect(dmLight.teal, const Color(0xFF087A72));
    expect(dmLight.tealSoft, const Color(0x14087A72));
    expect(dmLight.tealInk, const Color(0xFF0A6E67));
    expect(dmLight.amber, const Color(0xFFA85B10));
    expect(dmLight.amberSoft, const Color(0x12A85B10));
    expect(dmLight.examRed, const Color(0xFFB4271F));
    expect(dmLight.ok, const Color(0xFF1E7A46));
    expect(dmLight.navBg, const Color(0xFFFBFCFD));
    expect(dmLight.navRule, const Color(0xFFE4EAF0));
    expect(dmLight.danger, dmLight.examRed, reason: 'one red, one source');
  });

  test('dark tokens match DESIGN.md Night Desk table exactly', () {
    expect(dmDark.paper, const Color(0xFF19181A));
    expect(dmDark.elevated, const Color(0xFF211F22));
    expect(dmDark.sunk, const Color(0xFF141315));
    expect(dmDark.ink, const Color(0xFFECE6DC));
    expect(dmDark.ink2, const Color(0xFF9C9488));
    expect(dmDark.ink3, const Color(0xFF908878));
    expect(dmDark.rule, const Color(0xFF302D31));
    expect(dmDark.ruleStrong, const Color(0xFF3E3A3F));
    expect(dmDark.teal, const Color(0xFF3ED8C4));
    expect(dmDark.tealSoft, const Color(0x183ED8C4));
    expect(dmDark.tealInk, const Color(0xFF8CEBDD));
    expect(dmDark.amber, const Color(0xFFF2B44C));
    expect(dmDark.amberSoft, const Color(0x14F2B44C));
    expect(dmDark.examRed, const Color(0xFFF08A82));
    expect(dmDark.ok, const Color(0xFF5FCF8A));
    expect(dmDark.navBg, const Color(0xFF141315));
    expect(dmDark.navRule, const Color(0xFF2A282C));
  });

  test('type scale is the fixed 7 steps (DESIGN.md law)', () {
    expect(DmType.display.fontSize, 28);
    expect(DmType.display.fontFamily, 'SourceSerif4');
    expect(DmType.title.fontSize, 24);
    expect(DmType.section.fontSize, 19);
    expect(DmType.body.fontSize, 17);
    expect(DmType.body.fontFamily, 'SourceSerif4');
    expect(DmType.body.height, greaterThanOrEqualTo(1.55));
    expect(DmType.bodyUi.fontSize, 15);
    expect(DmType.bodyUi.fontFamily, 'Manrope');
    expect(DmType.meta.fontSize, 12.5);
    expect(DmType.label.fontSize, 11);
    expect(DmType.label.letterSpacing, closeTo(11 * 0.14, 0.001),
        reason: 'overline tracking is one value: 0.14em');
    expect(DmType.statNumber.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test('themes expose DmColors via context extension', () {
    final light = dmLightTheme();
    final dark = dmDarkTheme();
    expect(light.extension<DmTheme>()!.colors, dmLight);
    expect(dark.extension<DmTheme>()!.colors, dmDark);
    expect(light.scaffoldBackgroundColor, dmLight.paper);
    expect(dark.scaffoldBackgroundColor, dmDark.paper);
  });
}
