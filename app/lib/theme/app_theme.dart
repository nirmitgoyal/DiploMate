import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData dmLightTheme() => _base(dmLight, Brightness.light);
ThemeData dmDarkTheme() => _base(dmDark, Brightness.dark);

ThemeData _base(DmColors c, Brightness b) {
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: DmType.sans,
    scaffoldBackgroundColor: c.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.teal,
      brightness: b,
      surface: c.paper,
      error: c.examRed,
    ),
    dividerColor: c.rule,
    // No decorative shadows anywhere (anti-slop + D20).
    dialogTheme: DialogThemeData(
      backgroundColor: c.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DmRadius.md)),
    ),
    extensions: [DmTheme(c)],
  );
}
