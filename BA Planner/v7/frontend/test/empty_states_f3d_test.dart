// F3d: 빈 상태 안내 6장(시안 Empty-Scan · Empty-Student · Empty-Inventory · Empty-Plan · Empty-Stats · Empty-Tactical).
//
// 기본 `MockAppService()`는 여섯 탭 모두 빈 계정이다(확정 학생 0 · 인벤토리 0 · 활성 계획 없음 · 시나리오 0 · 이력 0 ·
// 전술 기록 0 · 스캔 기록 0). 검수 시나리오(`MockDesignReviewScenario`)는 모두 차 있어 안내가 없어야 한다.
// 탭마다 조건 · 버튼 동작을 보고, 1280×720에서도 넘침 예외 0을 본다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_design_review_scenario.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

const _reference = Size(2560, 1392);
const _small = Size(1280, 720);

/// 셸을 띄우고 [tab] 탭을 연다.
Future<MockAppService> _open(
  WidgetTester tester,
  String tab, {
  MockAppService? service,
  Size size = _reference,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final mock = service ?? MockAppService();
  addTearDown(mock.dispose);
  await tester.pumpWidget(BAPlannerApp(service: mock));
  await tester.pumpAndSettle();
  await tester.tap(_key('top-tab-$tab'));
  await tester.pumpAndSettle();
  return mock;
}

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    tester.widget<TonalButton>(_key(key)).onPressed;

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data;

void main() {
  group('scan', () {
    testWidgets('스캔 기록 0회면 안내 · 창 인식 타일만, 패널은 저절로 붙지 않는다', (tester) async {
      await _open(tester, 'scan');
      expect(_key('scan-empty-guide'), findsOneWidget);
      expect(_key('scan-empty-title'), findsOneWidget);
      expect(
        find.text('게임을 창 모드(1280×720 이상, 배율 100%)로 켜고 학생 목록 화면을 여십시오.'),
        findsOneWidget,
      );
      expect(_key('scan-pick-start'), findsNothing);
      expect(_key('scan-pick-student-full'), findsNothing);
      expect(_key('home-connect-panel'), findsNothing);
      expect(_text(tester, 'scan-empty-target-state'), '찾지 못함');
      expect(_text(tester, 'scan-empty-target-size'), '—');
      expect(_text(tester, 'scan-empty-target-game'), '—');
      expect(_text(tester, 'scan-empty-target-scale'), '—');
      expect(_onPressed(tester, 'scan-empty-find'), isNotNull);
      expect(_onPressed(tester, 'scan-empty-start'), isNull);
    });

    testWidgets('창 찾기 → 창 선택 패널 → 찾음(FB-4 크기 · game) → 스캔 시작', (tester) async {
      await _open(tester, 'scan');
      await tester.tap(_key('scan-empty-find'));
      await tester.pumpAndSettle();
      expect(_key('home-connect-panel'), findsOneWidget);
      await tester.tap(_key('home-connect-panel-row-mock-window'));
      await tester.pumpAndSettle();
      await tester.tap(_key('home-connect-panel-use'));
      await tester.pumpAndSettle();
      expect(_key('home-connect-panel'), findsNothing);
      expect(_text(tester, 'scan-empty-target-state'), '찾음');
      expect(_text(tester, 'scan-empty-target-size'), '2560×1440');
      expect(_text(tester, 'scan-empty-target-game'), 'Blue Archive');
      expect(_text(tester, 'scan-empty-target-scale'), '—');
      expect(_onPressed(tester, 'scan-empty-start'), isNotNull);

      await tester.tap(_key('scan-empty-start'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false))
          .controller;
      expect(controller.pick.studentScanMode, StudentScanMode.full);
      expect(controller.recent, isNotEmpty);
      expect(_key('scan-empty-guide'), findsNothing);
    });

    testWidgets('스캔 기록이 있으면 지금 고르기 화면 그대로', (tester) async {
      await _open(tester, 'scan', service: MockDesignReviewScenario());
      expect(_key('scan-empty-guide'), findsNothing);
      expect(_key('scan-pick-start'), findsOneWidget);
    });
  });

  group('students', () {
    testWidgets('확정 학생 0명이면 안내 · 점선 카드, 직접 입력은 비활성 + 이유', (tester) async {
      await _open(tester, 'students');
      expect(_key('student-empty-guide'), findsOneWidget);
      expect(_key('student-empty-cards'), findsOneWidget);
      expect(_key('student-section-2-grid-view'), findsNothing);
      expect(
        find.text('아직 확정된 학생이 없습니다. 학생 스캔을 한 번 하면 목록이 채워집니다.'),
        findsOneWidget,
      );
      expect(_onPressed(tester, 'student-empty-manual'), isNull);
      expect(_text(tester, 'student-empty-manual-reason'), '다음 버전에 들어갑니다');
      expect(_onPressed(tester, 'student-empty-open-scan'), isNotNull);
    });

    testWidgets('스캔하러 가기 → 스캔 탭', (tester) async {
      await _open(tester, 'students');
      await tester.tap(_key('student-empty-open-scan'));
      await tester.pumpAndSettle();
      expect(_key('scan-empty-guide'), findsOneWidget);
      expect(_key('student-empty-guide'), findsNothing);
    });

    testWidgets('확정 학생이 있으면 그리드 그대로', (tester) async {
      await _open(tester, 'students', service: MockDesignReviewScenario());
      expect(_key('student-empty-guide'), findsNothing);
      expect(_key('student-section-2-grid-view'), findsOneWidget);
    });
  });

  group('inventory', () {
    testWidgets('확정 인벤토리 0개면 부족한 것 보기에 안내, 전체 보기는 그대로', (tester) async {
      await _open(tester, 'inventory');
      expect(_key('inventory-empty-guide'), findsOneWidget);
      expect(
        find.text('인벤토리 스캔 전입니다. 아이템을 한 번 스캔하면 보유 수량이 채워집니다.'),
        findsOneWidget,
      );
      expect(_key('inventory-open-plan'), findsNothing);
      await tester.tap(_key('inventory-view-all'));
      await tester.pumpAndSettle();
      expect(_key('inventory-empty-guide'), findsNothing);
    });

    testWidgets('스캔하러 가기 → 스캔 탭', (tester) async {
      await _open(tester, 'inventory');
      await tester.tap(_key('inventory-empty-open-scan'));
      await tester.pumpAndSettle();
      expect(_key('scan-empty-guide'), findsOneWidget);
    });

    testWidgets('확정 인벤토리가 있으면 안내 없음', (tester) async {
      await _open(tester, 'inventory', service: MockDesignReviewScenario());
      expect(_key('inventory-empty-guide'), findsNothing);
    });
  });

  group('plan', () {
    testWidgets('활성 계획이 비면 S2에 안내 · 예시 한 줄, S3은 —', (tester) async {
      await _open(tester, 'plan');
      expect(_key('plan-empty-guide'), findsOneWidget);
      expect(find.text('학생을 고르고 목표를 정하면 필요한 재료가 계산됩니다.'), findsOneWidget);
      expect(find.text('크레딧 4.8M · 활동 보고서 (최상급) 38'), findsOneWidget);
      expect(_text(tester, 'plan-home-empty'), '—');
    });

    testWidgets('계획 만들기 → 계획 만들기 1단계', (tester) async {
      await _open(tester, 'plan');
      await tester.tap(_key('plan-empty-create'));
      await tester.pumpAndSettle();
      expect(_key('plan-flow-rail'), findsOneWidget);
    });

    testWidgets('활성 계획이 있으면 안내 없음', (tester) async {
      await _open(tester, 'plan', service: MockDesignReviewScenario());
      expect(_key('plan-empty-guide'), findsNothing);
    });

    // CF 검토: 2560×1392에서 키 큰 판 세로 가운데에 두면 왼쪽이 판 사선에 잘렸다. 안내 묶음 네 꼭짓점이 판
    // (`plan-home-phase-panel`, 80° 평행사변형) 사선 경계 안쪽이고, 시안처럼 판 위쪽 360 띠 안에 있어야 한다.
    for (final size in const [_small, _reference]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} 계획 안내 묶음은 판 사선 안쪽',
        (tester) async {
          await _open(tester, 'plan', size: size);
          final panel = tester.getRect(_key('plan-home-phase-panel'));
          final guide = tester.getRect(_key('plan-empty-guide'));
          double left(double y) =>
              panel.left + planPhaseLeftBoundary(panel.size, y - panel.top);
          double right(double y) =>
              panel.left + planPhaseRightBoundary(panel.size, y - panel.top);
          for (final corner in [guide.topLeft, guide.bottomLeft]) {
            expect(corner.dx, greaterThan(left(corner.dy)), reason: '$corner');
          }
          for (final corner in [guide.topRight, guide.bottomRight]) {
            expect(corner.dx, lessThan(right(corner.dy)), reason: '$corner');
          }
          expect(guide.top, greaterThan(panel.top));
          expect(guide.bottom, lessThanOrEqualTo(panel.top + 360));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('statistics', () {
    testWidgets('이력 스냅샷 0이면 가운데 섹션에 안내만(버튼 없음)', (tester) async {
      await _open(tester, 'statistics');
      expect(_key('statistics-empty-guide'), findsOneWidget);
      expect(find.text('스캔이 쌓이면 변화가 보입니다.'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('statistics-empty-guide'),
          matching: find.byType(TonalButton),
        ),
        findsNothing,
      );
      expect(_key('statistics-viewport-growth'), findsNothing);
    });

    testWidgets('이력이 있으면 안내 없음', (tester) async {
      await _open(tester, 'statistics', service: MockDesignReviewScenario());
      expect(_key('statistics-empty-guide'), findsNothing);
    });
  });

  group('tactical', () {
    testWidgets('기록 0건이면 S3에 "공격 기록" + 안내, 기록하기 → 새 기록 초안', (tester) async {
      await _open(tester, 'pvp');
      expect(_key('tactical-empty-guide'), findsOneWidget);
      expect(_text(tester, 'tactical-empty-title'), '공격 기록');
      expect(_key('tactical-editor-header'), findsNothing);
      await tester.tap(_key('tactical-empty-record'));
      await tester.pumpAndSettle();
      expect(_key('tactical-empty-guide'), findsNothing);
      expect(_text(tester, 'tactical-editor-header'), '새 공격 기록');
    });

    testWidgets('기록이 있으면 안내 없음', (tester) async {
      await _open(tester, 'pvp', service: MockDesignReviewScenario());
      expect(_key('tactical-empty-guide'), findsNothing);
      expect(_key('tactical-editor-header'), findsOneWidget);
    });
  });

  // F3c-4(FE10-z): 1280×720에서 계획 안내는 시안 폭 그대로면 ≈ 0.3배(제목 ≈ 6px)였다. 좁은 폭(예시 줄 없음)으로 그려
  // 다른 다섯 탭 빈 안내 중 가장 작은 글자(스캔 · 전술대항전 ≈ 0.44배) 이상이고, 잘린 줄이 없다. 2560×1392는 시안 폭 그대로.
  group('계획 안내 작은 창', () {
    double guideScale(WidgetTester tester, String guide) =>
        tester.getRect(_key(guide)).width /
        tester.renderObject<RenderBox>(_key(guide)).size.width;

    List<RenderParagraph> paragraphs(WidgetTester tester, String guide) {
      final found = <RenderParagraph>[];
      void visit(RenderObject node) {
        if (node is RenderParagraph) found.add(node);
        node.visitChildren(visit);
      }

      visit(tester.renderObject(_key(guide)));
      return found;
    }

    testWidgets('1280×720 제목 배율 ≥ 다른 다섯 탭의 최소, 잘린 줄 0', (tester) async {
      final others = <String, double>{};
      for (final (tab, guide) in const [
        ('scan', 'scan-empty-guide'),
        ('students', 'student-empty-guide'),
        ('inventory', 'inventory-empty-guide'),
        ('statistics', 'statistics-empty-guide'),
        ('pvp', 'tactical-empty-guide'),
      ]) {
        await _open(tester, tab, size: _small);
        others[tab] = guideScale(tester, guide);
      }
      await _open(tester, 'plan', size: _small);
      final scale = guideScale(tester, 'plan-empty-guide');
      final floor = others.values.reduce((a, b) => a < b ? a : b);
      expect(scale, greaterThanOrEqualTo(floor), reason: '$others');
      expect(19 * scale, greaterThan(8), reason: 'title px');
      expect(
        paragraphs(
          tester,
          'plan-empty-guide',
        ).where((p) => p.didExceedMaxLines),
        isEmpty,
      );
      expect(find.text('크레딧 4.8M · 활동 보고서 (최상급) 38'), findsNothing);
      expect(_key('plan-empty-create'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2560×1392는 시안 폭 · 예시 줄 그대로', (tester) async {
      await _open(tester, 'plan');
      expect(
        tester.renderObject<RenderBox>(_key('plan-empty-guide')).size.width,
        closeTo(776.8 - 83.5 * 2, 0.01),
      );
      expect(find.text('크레딧 4.8M · 활동 보고서 (최상급) 38'), findsOneWidget);
    });
  });

  group('1280×720', () {
    for (final (tab, guide) in const [
      ('scan', 'scan-empty-guide'),
      ('students', 'student-empty-guide'),
      ('inventory', 'inventory-empty-guide'),
      ('plan', 'plan-empty-guide'),
      ('statistics', 'statistics-empty-guide'),
      ('pvp', 'tactical-empty-guide'),
    ]) {
      testWidgets('$tab 빈 상태 넘침 0', (tester) async {
        await _open(tester, tab, size: _small);
        expect(find.byKey(ValueKey(guide)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
