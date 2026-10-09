/// 앱 색과 글꼴.
///
/// 깔끔한 밝은 회색 바탕 + 선명한 블루 강조 + 말하기는 코랄, 학습 포인트는 형광펜 노랑.
/// 글꼴은 전부 Pretendard(한글 + Inter 기반 영문, SIL OFL, 앱에 포함).
library;

import 'package:flutter/material.dart';

const _blue = Color(0xFF3E5BF2);
const _blueDark = Color(0xFF9BAEFF);
const _coral = Color(0xFFF2643E);
const _coralDark = Color(0xFFFF9C80);

const uiFont = 'Pretendard';

/// 영어 본문도 Pretendard(영문은 Inter 기반이라 한글과 결이 같다).
const englishFont = uiFont;
/// 숫자·시간 표시용. Pretendard 숫자는 폭이 고른 편이라 그대로 쓴다.
const monoFont = uiFont;

/// 테마에 없는 앱 전용 색.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.good, required this.subtleBorder});
  final Color good; // 맞은 단어, 높은 점수
  final Color subtleBorder; // 카드 테두리

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({Color? good, Color? subtleBorder}) =>
      AppColors(good: good ?? this.good, subtleBorder: subtleBorder ?? this.subtleBorder);

  @override
  AppColors lerp(AppColors? other, double t) => other == null
      ? this
      : AppColors(
          good: Color.lerp(good, other.good, t)!,
          subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
        );
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? const Color(0xFF0F1115) : const Color(0xFFF4F5F8);
  final card = dark ? const Color(0xFF191C22) : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: _blue,
    brightness: b,
    primary: dark ? _blueDark : _blue,
    tertiary: dark ? _coralDark : _coral,
    tertiaryContainer: dark ? const Color(0xFF4A2418) : const Color(0xFFFFE4DB),
    onTertiaryContainer: dark ? const Color(0xFFFFD9CC) : const Color(0xFF8A2A10),
    surface: card,
  );
  final border = dark ? const Color(0xFF262A33) : const Color(0xFFE6E8EE);

  final base = ThemeData(brightness: b, fontFamily: uiFont, colorScheme: scheme);
  final t = base.textTheme;
  TextStyle? tight(TextStyle? s, FontWeight w, [double ls = -0.3]) =>
      s?.copyWith(fontWeight: w, letterSpacing: ls);
  final textTheme = t.copyWith(
    displaySmall: tight(t.displaySmall, FontWeight.w700, -0.8),
    headlineLarge: tight(t.headlineLarge, FontWeight.w700, -0.8),
    headlineMedium: tight(t.headlineMedium, FontWeight.w700, -0.6),
    headlineSmall: tight(t.headlineSmall, FontWeight.w700, -0.5),
    titleLarge: tight(t.titleLarge, FontWeight.w700, -0.4),
    titleMedium: tight(t.titleMedium, FontWeight.w600),
    titleSmall: tight(t.titleSmall, FontWeight.w600, -0.1),
    labelLarge: tight(t.labelLarge, FontWeight.w600, 0),
    bodyLarge: t.bodyLarge?.copyWith(letterSpacing: -0.1, height: 1.5),
    bodyMedium: t.bodyMedium?.copyWith(letterSpacing: -0.1, height: 1.45),
  );
  final rounded14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const btnText = TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w600);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: bg,
    extensions: [
      AppColors(
        good: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
        subtleBorder: border,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface, fontSize: 20),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: uiFont,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
          )),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: btnText,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded14,
        textStyle: btnText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded14,
        side: BorderSide(color: border, width: 1.2),
        textStyle: btnText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: rounded14, textStyle: btnText),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: rounded14,
        side: BorderSide(color: border),
        selectedBackgroundColor: scheme.primaryContainer,
        textStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600),
      ),
    ),
    // 칩 글자색은 꼭 명시한다(빠뜨리면 선택된 칩 글자가 흰색으로 나와 안 보였음).
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: border),
      backgroundColor: card,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
      iconTheme: IconThemeData(color: scheme.primary, size: 18),
      labelStyle: TextStyle(
        fontFamily: uiFont,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: uiFont,
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF20242C) : const Color(0xFFF1F2F6),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: dark ? const Color(0xFF262A33) : const Color(0xFFE6E8EE),
    ),
  );
}

/// 형광펜 색. 다크 모드에서는 글자가 읽히도록 투명도를 낮춘다.
Color markerColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0x59F5D547)
        : const Color(0xA6FFE45C);

/// 지금 재생 중인 줄/문장의 배경.
Color currentLineColor(BuildContext context) =>
    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45);

TextStyle englishStyle(BuildContext context, {double size = 18}) => TextStyle(
      fontFamily: englishFont,
      fontSize: size,
      height: 1.5,
      letterSpacing: -0.2,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onSurface,
    );
