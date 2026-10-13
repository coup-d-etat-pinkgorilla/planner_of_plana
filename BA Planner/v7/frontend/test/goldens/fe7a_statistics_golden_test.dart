// FE7-a golden: 통계 탭 골격(시안 Stats-Growth의 3섹션 · KPI 띠 · 위젯 타일 배치).
// FE7-b: 학생 성장 KPI 값 · A1 육성도 분포 · A2 항목별 완성도가 채워진다. fixture 입력만 바꿨다(장면 조작은 그대로).
//
// 앱 셸 → 통계 탭(기본 주제 "학생 성장"). Mock 기본 계정의 계정 상태 · 학생 목록을 시안 숫자 fixture
// (`statistics_growth_fixture.dart`: 보유 128 / 170, 60~70% 구간 22명, 평균 63.4%, 최대 레벨 64명, 계획 등록 9명)로
// 바꿔 사용자가 캔버스와 같은 숫자로 비교하게 한다. 구간을 고르지 않은 상태라 근거 패널은 빈 상태 문구다.
// 기준 데이터 · 증감은 '—', A3 · A4 · A5 · A6은 "준비 중"이다(FD-106 사용자 결정 10-13).
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'dart:convert';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../statistics_growth_fixture.dart';
import 'golden_harness.dart';

/// golden Mock 위에 학생 성장 fixture(계정 상태 학생 · 목표, 학생 목록)만 바꿔 끼운다. 인벤토리는 Mock 그대로다.
class _GrowthGoldenService extends GoldenMockAppService {
  List<StudentCatalogEntry>? _catalog;

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    final base = await super.loadRepositoryState(profileId);
    return statisticsGrowthFixtureState(
      profileId: base.profileId,
      revision: base.revision,
      inventory: base.inventory.toWire(),
    );
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() async {
    final cached = _catalog;
    if (cached != null) return cached;
    // 번들 학생 목록에서 fixture id(이름 · 초상 · 애장품 여부가 실제 값)를 고른다. Mock처럼 bytes를 직접 읽는다.
    final data = await rootBundle.load('assets/student_catalog.json');
    final byId = {
      for (final item in jsonDecode(utf8.decode(data.buffer.asUint8List())) as List)
        (item as Map)['student_id'] as String: StudentCatalogEntry.fromWire(
          Map<String, dynamic>.from(item),
        ),
    };
    return _catalog = [
      for (final id in statisticsGrowthFixtureCatalogIds) byId[id]!,
    ];
  }
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('statistics-growth', (tester) async {
    setGoldenViewport(tester);
    final service = _GrowthGoldenService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('top-tab-statistics'));
    expect(tab, findsOneWidget, reason: 'golden navigation key top-tab-statistics');
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text(statisticsEvidenceEmptyText));
    expect(find.byKey(const ValueKey('statistics-tile-A1')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-kpis-growth')), findsOneWidget);
    await expectGoldenScene(tester, 'statistics-growth');
  }, variant: goldenPlatform);
}
