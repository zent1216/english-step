/// 앱 색과 글꼴. 차분한 청회색 바탕 + 잉크 블루 강조 + 학습 포인트는 형광펜 노랑.
library;

import 'package:flutter/material.dart';

const _ink = Color(0xFF24477F);
const _inkDark = Color(0xFFA9C2EE);

/// 영어 본문용 세리프(기기 기본 세리프, 안드로이드는 Noto Serif). 별도 글꼴 다운로드 없음.
const englishFont = 'serif';
const monoFont = 'monospace';

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _ink,
    brightness: b,
    primary: dark ? _inkDark : _ink,
    surface: dark ? const Color(0xFF181D24) : const Color(0xFFF9FAFB),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF11151A) : const Color(0xFFE9EDF1),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF11151A) : const Color(0xFFE9EDF1),
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// 형광펜 색. 다크 모드에서는 글자가 읽히도록 투명도를 낮춘다.
Color markerColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0x59F5D547)
        : const Color(0xB3FFE45C);

/// 지금 재생 중인 줄/문장의 연한 노랑 배경.
Color currentLineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0x26F5D547)
        : const Color(0x66FFF3B0);

TextStyle englishStyle(BuildContext context, {double size = 18}) => TextStyle(
      fontFamily: englishFont,
      fontSize: size,
      height: 1.55,
      color: Theme.of(context).colorScheme.onSurface,
    );
