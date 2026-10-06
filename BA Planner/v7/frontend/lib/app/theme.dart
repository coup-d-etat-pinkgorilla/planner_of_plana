import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xff101722);
  static const navigation = Color(0xff172230);
  static const surface = Color(0xff1d2a3a);
  static const surfaceRaised = Color(0xff243448);
  static const outline = Color(0xff38516b);
  static const primary = Color(0xff71c7f4);
  static const primaryMuted = Color(0xff25587b);
  static const text = Color(0xfff4f8fb);
  static const textMuted = Color(0xff9eb0c2);
  static const success = Color(0xff58d6a7);
  static const warning = Color(0xffffc66d);
  static const danger = Color(0xffff7e8a);
}

abstract final class AppSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// 서체 가족의 역할 분리.
///
/// `display`(경기천년제목)는 이름 그대로 제목용 서체다. 큰 글자에서 BA Planner의
/// 인상을 만드는 자리에만 쓰고, 실제로 읽어야 하는 본문·데이터·라벨은 `body`가
/// 담당한다. 이전 구현은 제목용 서체 하나를 8.5~12px 본문에까지 전역으로 적용해
/// 가독성과 굵기 위계를 모두 잃었다.
abstract final class AppFonts {
  /// 본문·데이터·라벨. 400/500/600/700 네 굵기가 실제 파일로 등록되어 있다.
  static const body = 'Pretendard';

  /// 제목·타이틀 화면 등 큰 글자 전용. 굵기는 500 한 종뿐이다.
  static const display = 'GyeonggiTitle';

  /// Pretendard가 못 덮는 글리프(희귀 한자, 일부 기호)를 위한 시스템 폴백.
  /// 폴백이 없으면 혼합 문자열에서 자폭과 베이스라인이 흔들린다.
  static const fallback = <String>[
    'Malgun Gothic',
    'Segoe UI',
    'Apple SD Gothic Neo',
  ];
}

/// 화면 전체가 공유하는 타이포 스케일.
///
/// 규칙은 세 가지다.
///
/// 1. **크기는 이 목록에서만 고른다.** 이전에는 7.5~43.2 사이에 32종의 크기가
///    흩어져 있어서 어떤 값이 의도된 위계이고 어떤 값이 임기응변인지 구분할 수
///    없었다.
/// 2. **행간(`height`)을 0으로 두지 않는다.** 한글은 라틴보다 글자면이 커서
///    행간 1.0이면 글자끼리 붙어 보인다. 조밀한 자리도 최소 1.2를 준다.
/// 3. **굵기는 위계를 만들 때만 올린다.** 본문 기본은 500이고, 강조가 600,
///    제목이 700이다. 전부 굵게 만들면 아무것도 강조되지 않는다.
abstract final class AppType {
  // --- 크기 토큰 ------------------------------------------------------------
  /// 배지, 증감 표시처럼 한두 글자만 들어가는 최소 크기. 이보다 작게 쓰지 않는다.
  static const microSize = 10.0;
  static const captionSize = 11.0;
  static const bodySmallSize = 12.0;
  static const bodySize = 13.0;
  static const bodyLargeSize = 15.0;
  static const titleSmallSize = 14.0;
  static const titleSize = 16.0;
  static const titleLargeSize = 18.0;
  static const headlineSize = 20.0;
  static const headlineLargeSize = 24.0;
  static const displaySize = 28.0;
  static const displayLargeSize = 36.0;

  // --- 굵기 토큰 ------------------------------------------------------------
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semiBold = FontWeight.w600;
  static const bold = FontWeight.w700;

  // --- 본문 계열 ------------------------------------------------------------
  static const micro = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: microSize,
    height: 1.2,
    fontWeight: medium,
  );

  static const caption = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: captionSize,
    height: 1.35,
    fontWeight: medium,
  );

  static const bodySmall = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: bodySmallSize,
    height: 1.45,
    fontWeight: medium,
  );

  static const body = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: bodySize,
    height: 1.5,
    fontWeight: medium,
  );

  static const bodyLarge = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: bodyLargeSize,
    height: 1.5,
    fontWeight: medium,
  );

  // --- 제목 계열 ------------------------------------------------------------
  static const titleSmall = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: titleSmallSize,
    height: 1.35,
    fontWeight: semiBold,
  );

  static const title = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: titleSize,
    height: 1.35,
    fontWeight: semiBold,
  );

  static const titleLarge = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: titleLargeSize,
    height: 1.3,
    fontWeight: semiBold,
  );

  static const headline = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: headlineSize,
    height: 1.28,
    fontWeight: bold,
  );

  static const headlineLarge = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: headlineLargeSize,
    height: 1.25,
    fontWeight: bold,
  );

  // --- 제목용 서체(경기천년제목) 전용 -----------------------------------------
  // 20px 미만에는 쓰지 않는다. 작은 크기에서 본문 서체보다 확연히 읽기 어렵다.
  static const displayBrand = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: displaySize,
    height: 1.18,
  );

  static const displayBrandLarge = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: displayLargeSize,
    height: 1.12,
  );

  /// 숫자 열이 세로로 정렬되어야 하는 자리(레벨, 보유량, 필요량, 부족량, 증감)에
  /// 쓴다. `tnum`은 모든 숫자에 같은 자폭을 주므로 값이 바뀌어도 자리가 흔들리지
  /// 않는다. 비교가 목적인 화면에서는 장식이 아니라 기능이다.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

abstract final class AppTextStyles {
  /// 페이즈 카드의 기하가 17px에 맞춰져 있어 크기는 그대로 둔다. 카드 레이아웃을
  /// 다시 볼 때 `AppType.titleLarge`로 올린다.
  static final planPhaseNumber = AppType.tabular(
    AppType.titleLarge.copyWith(
      color: const Color(0xfff2b3ef),
      fontSize: 17,
      fontWeight: AppType.bold,
    ),
  );
}

abstract final class BAPlannerTheme {
  static TextTheme _textTheme() => TextTheme(
    displayLarge: AppType.displayBrandLarge.copyWith(color: AppColors.text),
    displayMedium: AppType.displayBrand.copyWith(color: AppColors.text),
    displaySmall: AppType.displayBrand.copyWith(
      color: AppColors.text,
      fontSize: AppType.headlineLargeSize,
    ),
    headlineLarge: AppType.headlineLarge.copyWith(color: AppColors.text),
    headlineMedium: AppType.headline.copyWith(color: AppColors.text),
    headlineSmall: AppType.headline.copyWith(color: AppColors.text),
    titleLarge: AppType.titleLarge.copyWith(color: AppColors.text),
    titleMedium: AppType.title.copyWith(color: AppColors.text),
    titleSmall: AppType.titleSmall.copyWith(color: AppColors.text),
    bodyLarge: AppType.bodyLarge.copyWith(color: AppColors.text),
    bodyMedium: AppType.body.copyWith(color: AppColors.text),
    bodySmall: AppType.bodySmall.copyWith(color: AppColors.textMuted),
    labelLarge: AppType.body.copyWith(
      color: AppColors.text,
      fontWeight: AppType.semiBold,
    ),
    labelMedium: AppType.caption.copyWith(
      color: AppColors.textMuted,
      fontWeight: AppType.semiBold,
    ),
    labelSmall: AppType.micro.copyWith(
      color: AppColors.textMuted,
      fontWeight: AppType.semiBold,
    ),
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: _textTheme(),
      dividerColor: AppColors.outline,
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: AppType.body.copyWith(fontWeight: AppType.semiBold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppType.body.copyWith(fontWeight: AppType.semiBold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppType.body.copyWith(color: AppColors.textMuted),
        labelStyle: AppType.bodySmall.copyWith(color: AppColors.textMuted),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: AppType.bodySmall.copyWith(color: AppColors.text),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outline),
        ),
      ),
    );
  }
}
