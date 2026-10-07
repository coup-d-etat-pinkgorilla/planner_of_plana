import 'package:flutter/material.dart';

/// 색 토큰.
///
/// 역할 규칙(FD-005): **선택·강조 = 핑크 `accent`, 탐색(주 탭 선택) = 파랑
/// `primary`**. 값은 2026-10-05 확정 시안의 CSS 값을 그대로 옮긴 것이다.
/// 알파는 토큰에 굽지 않고 쓰는 자리에서 `withValues(alpha: …)`로 준다
/// (예: 섹션 표면 `surface`@.76, 행 배경 `rowSurface`@.72).
abstract final class AppColors {
  // --- 표면·선 -------------------------------------------------------------
  static const canvas = Color(0xff101722);
  static const navigation = Color(0xff172230);

  /// 섹션 표면의 기준색. 모든 섹션은 이 색 @.76, 블러 없음, 테두리 없음, 아래에 lifted shadow
  /// 4층으로 그린다(FD-006·FD-007). 직접 칠하지 말고 `ui/widgets/section_surface.dart`의
  /// `SectionSurface`·`paintSectionSurface`·`sectionSurfaceColor`를 쓴다.
  static const surface = Color(0xff1d2a3a);
  static const surfaceRaised = Color(0xff243448);
  static const outline = Color(0xff38516b);

  /// 팝오버·모달 패널 배경(시안 `#0d151f`).
  static const popover = Color(0xff0d151f);

  /// 사선 행·타일·세그먼트 배경의 기준색(시안 `rgba(16,24,35,·)`).
  /// 알파는 쓰는 자리에서 준다: 행 .72, 타일 .6, 세그먼트 .9, 차트 .55.
  static const rowSurface = Color(0xff101823);

  /// KPI 타일·학생 상세 인디케이터 상자(시안 `#203243`).
  static const indicatorSurface = Color(0xff203243);

  /// 모달 스크림의 기준색(시안 `rgba(6,10,16,·)`). 알파 프리셋은 FE2-c의
  /// `BaModal`이 가진다(FD-013).
  static const scrim = Color(0xff060a10);

  // --- 탐색·강조 -----------------------------------------------------------
  static const primary = Color(0xff71c7f4);
  static const primaryMuted = Color(0xff25587b);

  /// 선택·강조 핑크(시안 `#f2b3ef`): 선택 행 막대, 세그먼트 on 테두리,
  /// 제목 막대, 부족량, 흐름 삼각형.
  static const accent = Color(0xfff2b3ef);

  /// 핑크 표면 위의 밝은 글자(시안 `#f7c9f4`).
  static const accentText = Color(0xfff7c9f4);

  /// 핑크로 채운 배경 위의 글자(시안 `#2a1330`).
  static const onAccent = Color(0xff2a1330);

  /// 사선 스크롤바 썸(시안 `#e5a0ea`).
  static const scrollThumb = Color(0xffe5a0ea);

  // --- 글자 ----------------------------------------------------------------
  /// 본문. 시안의 거의 흰 변형(#dfe7ee/#e6edf3/#dbe4ec)도 이 값으로 통합한다
  /// (FD-011).
  static const text = Color(0xfff4f8fb);

  /// 2차 본문: 세그먼트 라벨, 팝오버 본문(시안 `#c3cfdb`).
  static const textSecondary = Color(0xffc3cfdb);
  static const textMuted = Color(0xff9eb0c2);

  /// 차트 축 라벨처럼 가장 약한 글자(시안 `#6f8397`).
  static const textDim = Color(0xff6f8397);

  // --- 상태 ----------------------------------------------------------------
  static const success = Color(0xff58d6a7);
  static const warning = Color(0xffffc66d);
  static const danger = Color(0xffff7e8a);

  // --- 성작 노랑(FD-012: 두 값 모두 시안 값이므로 둘 다 둔다) -------------
  /// 학생 성작 표시(9칸 인디케이터의 학생 5칸).
  static const starDisplay = Color(0xfff3c96b);

  /// 성급 범위 필터의 학생 칸.
  static const starFilter = Color(0xffe8c15a);

  // --- 공격·방어 타입 5색(FD-024) -----------------------------------------
  // 방어 타입은 같은 색을 공유한다: 경장갑=폭발, 중장갑=관통, 특수장갑=신비,
  // 탄력장갑=진동, 복합장갑=composite.
  static const typeExplosive = Color(0xff920008);
  static const typePiercing = Color(0xffbd8901);
  static const typeMystic = Color(0xff226f9b);
  static const typeSonic = Color(0xff9945a8);

  /// 복합장갑(시안 `#7a8ea3`). 학생 카드 칩과 갤러리 타입 칩이 쓴다(FE3-a에서 옛
  /// `#228b22`를 이 토큰으로 바꿨다).
  static const typeComposite = Color(0xff7a8ea3);
}

/// 칩 한 색의 배경·글자 쌍. 배경은 `base`에 `backgroundAlpha`를 준 색이다.
@immutable
final class AppTone {
  const AppTone({
    required this.base,
    required this.backgroundAlpha,
    required this.foreground,
  });

  final Color base;
  final double backgroundAlpha;
  final Color foreground;

  Color get background => base.withValues(alpha: backgroundAlpha);
}

/// 시안 `.chip` 6색(정보/pk/ok/wn/dg/gy)의 tone 쌍.
abstract final class AppTones {
  static const info = AppTone(
    base: AppColors.primary,
    backgroundAlpha: 0.16,
    foreground: Color(0xffa8e0ff),
  );
  static const pink = AppTone(
    base: AppColors.accent,
    backgroundAlpha: 0.2,
    foreground: AppColors.accentText,
  );
  static const ok = AppTone(
    base: AppColors.success,
    backgroundAlpha: 0.16,
    foreground: Color(0xff7fe3bd),
  );
  static const warn = AppTone(
    base: AppColors.warning,
    backgroundAlpha: 0.16,
    foreground: Color(0xffffd08a),
  );
  static const danger = AppTone(
    base: AppColors.danger,
    backgroundAlpha: 0.16,
    foreground: Color(0xffffa0a8),
  );
  static const gray = AppTone(
    base: AppColors.textMuted,
    backgroundAlpha: 0.14,
    foreground: AppColors.textSecondary,
  );

  static const all = <AppTone>[info, pink, ok, warn, danger, gray];
}

/// 모션 토큰(FD-017). 값과 곡선은 기존 구현 그대로다.
abstract final class AppMotion {
  /// 섹션 intro/outro.
  static const section = Duration(milliseconds: 360);

  /// 섹션 intro/outro와 셸 모션이 함께 쓰는 곡선.
  static const sectionCurve = Curves.easeInOutCubic;

  /// `DirectionalSectionEntrance`의 진입 곡선.
  static const entranceCurve = Curves.easeOutCubic;

  /// 셸(홈 진입, 타이틀 퇴장, 계정 클러스터) 모션.
  static const shell = Duration(milliseconds: 460);

  /// 탭 본문 전환(`AnimatedSectionStack`) 네 구간과 합계 970ms.
  static const tabBodyPull = Duration(milliseconds: 120);
  static const tabBodyExit = Duration(milliseconds: 300);
  static const tabBodyEnter = Duration(milliseconds: 360);
  static const tabBodySettle = Duration(milliseconds: 190);
  static const tabBody = Duration(milliseconds: 120 + 300 + 360 + 190);

  /// 헤더 콘텐츠 교체(fade + slide).
  static const header = Duration(milliseconds: 220);

  /// 주 탭 선택 배경.
  static const tab = Duration(milliseconds: 180);
}

/// 모서리 반경 토큰.
abstract final class AppRadii {
  /// 섹션 둥근 다각형, 카드.
  static const section = 14.0;

  /// tonal·filled 버튼, 입력창.
  static const control = 10.0;

  /// 주 탭 윗모서리, 툴팁.
  static const tab = 8.0;
  static const tooltip = 8.0;

  /// 사선 행 path(시안 빈도 r8 > r12 > r10).
  static const row = 8.0;
  static const rowLarge = 12.0;

  /// 시안 `.chip`.
  static const chip = 7.0;

  /// 스큐 요소(세그먼트, 토글 칩, 단계 태그).
  static const skew = 5.0;

  /// 토글 스위치 `.tog`.
  static const toggle = 11.0;
}

/// 컨트롤 높이 토큰(시안 기준).
abstract final class AppControlHeights {
  static const tab = 44.0;
  static const chip = 24.0;
  static const segmented = 36.0;
  static const toggleChip = 30.0;
  static const tonalButton = 40.0;
  static const toggle = 22.0;
  static const stepper = 24.0;
  static const info = 24.0;
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
/// `display`(경기천년제목)는 값·제목 서체다. 시안(FD-001 시안 우선)은 큰 제목뿐
/// 아니라 값·소제목(`.dsp`, `.ihdr`, 스테퍼 값)에도 크기 제한 없이 쓴다(FD-008).
/// 문장으로 읽어야 하는 본문·데이터·라벨은 여전히 `body`가 담당한다. 이전 구현은
/// 제목용 서체 하나를 본문에까지 전역으로 적용해 가독성과 굵기 위계를 모두 잃었다.
abstract final class AppFonts {
  /// 본문·데이터·라벨. 400/500/600/700 네 굵기가 실제 파일로 등록되어 있다.
  static const body = 'Pretendard';

  /// 값·제목 서체. 크기 제한은 없다(FD-008): 시안은 6.5~43px의 값·소제목에도
  /// 쓴다. 굵기는 500 한 종뿐이다.
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
/// 1. **크기는 이 목록에서만 고른다.** 기본 스케일 아래에 시안 전용 크기를
///    역할 토큰으로 둔다(FD-010). 가까운 토큰으로 스냅하지 않는다. 캔버스와
///    나란히 비교하면 스냅이 차이를 만든다.
/// 2. **행간(`height`)을 0으로 두지 않는다.** 한글은 라틴보다 글자면이 커서
///    행간 1.0이면 글자끼리 붙어 보인다. 조밀한 자리도 최소 1.2를 준다.
/// 3. **굵기는 위계를 만들 때만 올린다.** 본문 기본은 500이고, 강조가 600,
///    제목이 700이다. 전부 굵게 만들면 아무것도 강조되지 않는다.
///    시안의 800/900은 Pretendard 파일이 없으므로 새 코드에서 `bold`(700)로
///    쓴다(FD-009). 기존 `w800`/`w900` 사용처는 렌더 결과가 바뀔 수 있어
///    FE1-a에서 손대지 않고 각 화면 slice에서 캔버스와 대조해 정리한다.
abstract final class AppType {
  // --- 크기 토큰 ------------------------------------------------------------
  /// 배지, 증감 표시처럼 한두 글자만 들어가는 기본 스케일의 최소 크기.
  /// 10 미만은 아래 시안 전용 크기 토큰으로만 쓴다(FD-010).
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

  // --- 시안 전용 크기 토큰(FD-010) ------------------------------------------
  // 역할이 확인된 크기는 역할 이름, 그 밖의 반 단계·중간 크기는 기본 스케일 사이의
  // 위치로 이름을 붙인다. 10 미만은 학생 인디케이터·mrow 내부 라벨용이다.
  static const indicatorHeaderSize = 8.0; // `.ihdr` 소제목(경기천년제목)
  static const microDenseSize = 8.5;
  static const indicatorLabelSize = 9.0; // `.ilab`
  static const microDenseLargeSize = 9.5;
  static const microPlusSize = 10.5;
  static const captionPlusSize = 11.5;
  static const popoverBodySize = 12.5; // `.pop` (i) 팝오버 본문
  static const bodyPlusSize = 13.5;
  static const stepperGlyphSize = 16.5; // `.stp` 스테퍼 ±
  static const titleMediumSize = 17.0;
  static const panelTitleSize = 19.0; // PanelTitle `.dsp`
  static const headlineSmallSize = 21.0;
  static const headlineMediumSize = 22.0;
  static const stepperValueSize = 25.2; // 스테퍼 값(경기천년제목)
  static const displaySmallSize = 26.0;
  static const displayMediumSize = 30.0;
  static const displayLargePlusSize = 34.0;
  static const heroValueSize = 43.2;

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

  // --- 제목용 서체(경기천년제목) -------------------------------------------
  // 값·제목 서체이며 크기 제한은 없다(FD-008, 시안 우선 FD-001). 작은 크기는
  // 위의 시안 전용 크기 토큰과 함께 `fontFamily: AppFonts.display`로 쓴다.
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
      color: AppColors.accent,
      fontSize: AppType.titleMediumSize,
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
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.section)),
          side: BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: AppType.body.copyWith(fontWeight: AppType.semiBold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
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
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: AppType.bodySmall.copyWith(color: AppColors.text),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadii.tooltip),
          border: Border.all(color: AppColors.outline),
        ),
      ),
    );
  }
}
