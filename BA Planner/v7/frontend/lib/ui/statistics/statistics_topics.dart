// 통계 주제 3개와 주제별 골격(FE7-a, 시안 Stats-Growth · Stats-Inventory · Stats-Plan, F 보고서 §2·§3).
//
// 주제마다 왼쪽 주제 버튼 글자, 가운데 제목 · (i) 도움말 · 범위 글자, KPI 다섯 칸의 라벨, 위젯 타일 줄, 오른쪽 아래
// 이동 버튼 글자를 둔다. 타일 폭 · 높이 · 순서는 시안 타일 rect, 차수(1·2·3차)는 Statistics-Proposal 기능 카드 표다.
// 값: 학생 성장의 KPI · 보유 인원은 FE7-b부터, 인벤토리 · 계획 KPI · 계획 학생 수는 FE7-c부터 채운다. 기준 시각 · 증감 ·
// 페이즈 수(활성 문서, FE7-g)는 아직 '—'다.
import 'package:flutter/foundation.dart';

import '../geometry/diagonal_geometry.dart';
import '../studio/statistics_studio_layout.dart';

/// 통계 주제(F §4 "모드 3개는 그대로 대응한다"): A 학생 성장 · B 인벤토리 현황 · C 계획 집계.
enum StatisticsMode { students, inventory, plan }

/// 위젯 타일 하나(시안 `.tile`). [width]는 기준 viewport의 시안 폭이고, 줄 안 비율로만 쓴다.
@immutable
class StatisticsTileSpec {
  const StatisticsTileSpec(
    this.id,
    this.title,
    this.order,
    this.width, {
    this.segments = const [],
    this.showsOrderChip = true,
  });

  /// 시안 위젯 ID(A1 · B2 · C3 …).
  final String id;
  final String title;

  /// 구현 차수(Statistics-Proposal "1차 · 2차 · 3차" 칩).
  final int order;
  final double width;

  /// 시안 머리 seg 글자(첫 칸이 선택). A1 seg는 FE7-b부터 성장 자료가 있을 때 동작하고, 나머지는 그래프 slice 전까지 비활성 자리다.
  final List<String> segments;

  /// 시안 머리에 차수 칩이 있는가. seg만 있는 타일(A1 · A4 · B2 · C1)은 없고, B3은 seg와 칩이 함께 있다.
  final bool showsOrderChip;

  String get orderLabel => '$order차';
}

/// 위젯 타일 한 줄. 같은 줄 타일은 높이가 같다(시안).
@immutable
class StatisticsTileRow {
  const StatisticsTileRow(this.height, this.tiles);

  /// 기준 viewport의 시안 높이. 다른 창 크기에서는 [statisticsTileScale]을 곱한다.
  final double height;
  final List<StatisticsTileSpec> tiles;
}

/// 오른쪽 아래 이동 버튼 글자(행동 + 목적지 설명). 이동은 FE7-d라 지금은 누를 수 없다.
@immutable
class StatisticsEvidenceAction {
  const StatisticsEvidenceAction(this.label, [this.detail]);

  final String label;
  final String? detail;
}

extension StatisticsModeSpec on StatisticsMode {
  String get key => switch (this) {
    StatisticsMode.students => 'growth',
    StatisticsMode.inventory => 'inventory',
    StatisticsMode.plan => 'plan',
  };

  /// 주제 버튼 · 가운데 제목.
  String get label => switch (this) {
    StatisticsMode.students => '학생 성장',
    StatisticsMode.inventory => '인벤토리 현황',
    StatisticsMode.plan => '계획 집계',
  };

  /// 주제 버튼 부제.
  String get subtitle => switch (this) {
    StatisticsMode.students => 'A · 육성도 · 항목 · 성작 · 학교',
    StatisticsMode.inventory => 'B · 충족률 · 부족/과잉 · 변화',
    StatisticsMode.plan => 'C · 필요량 · 병목 · 진행',
  };

  /// 가운데 제목 옆 (i) 도움말 본문(시안 `.pop.l`).
  String get help => switch (this) {
    StatisticsMode.students =>
      '막대 · 점 · 칸을 누르면 오른쪽에 그 구간 학생이 나오고, 학생 탭으로 넘길 수 있습니다. 가운데 영역은 세로로 스크롤됩니다.',
    StatisticsMode.inventory =>
      '활성 계획에 필요한 재화만 셉니다. 종류마다 단위가 달라 수량을 더하지 않고 충족률(%)로 비교합니다. 스캔이 없는 재화는 0이 아니라 빗금입니다.',
    StatisticsMode.plan =>
      '§6 병목 기준: 단계 순서대로 보유량을 차감해 처음 모자라는 단계와 그 뒤에 쌓이는 부족을 셉니다.',
  };

  /// 가운데 제목 줄 오른쪽 범위 글자. 계획 집계는 칩이다(시안).
  String get scope => scopeFor(null);

  /// [owned]는 보유 학생 수(학생 성장, FE7-b), [planStudents]는 계획(사용자 목표) 학생 수(계획 집계, FE7-c). 모르면 '—'다.
  /// 계획 페이즈 수는 활성 문서 계산(FE7-g) 전이라 '—'다.
  String scopeFor(int? owned, {int? planStudents}) => switch (this) {
    StatisticsMode.students => '보유 ${owned ?? '—'}명 기준 · 지난 스냅샷 대비',
    StatisticsMode.inventory => '활성 계획 기준 · 인벤토리 스캔 —',
    StatisticsMode.plan => '활성 계획 · ${planStudents ?? '—'}명 · 페이즈 —',
  };

  bool get scopeIsChip => this == StatisticsMode.plan;

  /// 왼쪽 필터 버튼 부제. 필터는 학생 성장에만 걸린다(FD-104, 확정 사항 1).
  String get filterNote => filterNoteFor(null);

  /// [owned]는 보유 학생 수(FE7-b). 모르면 '—'다.
  String filterNoteFor(int? owned) => switch (this) {
    StatisticsMode.students => '없음 · 보유 ${owned ?? '—'}명 전체',
    StatisticsMode.inventory ||
    StatisticsMode.plan => '인벤토리 · 계획 집계는 항상 전체',
  };

  /// KPI 다섯 칸 라벨(FD-105 권장안: 주제별 5개).
  List<String> get kpiLabels => switch (this) {
    StatisticsMode.students => const [
      '보유 학생',
      '평균 육성도',
      '최대 레벨',
      '완전 육성',
      '계획 등록',
    ],
    StatisticsMode.inventory => const [
      '전체 충족률',
      '부족 재화',
      '과잉 재화',
      '충족 카테고리',
      '스캔 없음',
    ],
    StatisticsMode.plan => const [
      '계획 충족률',
      '부족 재화',
      '첫 부족',
      '막힌 학생',
      '미계획 · 40% 미만',
    ],
  };

  /// KPI 칸을 누르면 스크롤할 타일 줄(FD-105: 같은 주제 안 그래프). 성장 · 인벤토리는 모두 첫 줄(A1 · A2 / B1),
  /// 계획은 계획 충족률 · 부족 재화 → C1, 첫 부족 → C3, 막힌 학생 → C2(첫 줄), 미계획 → C5.
  List<int> get kpiTargetRows => switch (this) {
    StatisticsMode.students || StatisticsMode.inventory => const [0, 0, 0, 0, 0],
    StatisticsMode.plan => const [0, 0, 1, 0, 2],
  };

  /// 위젯 타일 줄(시안 순서 · 위치 · 머리 글자 · seg · 차수 칩 유무).
  List<StatisticsTileRow> get rows => switch (this) {
    StatisticsMode.students => const [
      StatisticsTileRow(322, [
        StatisticsTileSpec(
          'A1',
          '육성도 분포',
          1,
          791.4,
          segments: ['육성도', '레벨', '스킬', '장비'],
          showsOrderChip: false,
        ),
        StatisticsTileSpec('A2', '항목별 완성도', 1, 695.5),
      ]),
      StatisticsTileRow(368, [
        StatisticsTileSpec(
          'A4',
          '학교 비교',
          2,
          751.6,
          segments: ['학교', '역할'],
          showsOrderChip: false,
        ),
        StatisticsTileSpec('A6', '성장 추이', 2, 751.6),
      ]),
      StatisticsTileRow(313, [
        StatisticsTileSpec('A3', '성작 · 전용무기', 2, 741.9),
        StatisticsTileSpec('A5', '스킬 · 장비 매트릭스', 3, 741.9),
      ]),
    ],
    StatisticsMode.inventory => const [
      StatisticsTileRow(313, [
        StatisticsTileSpec('B1', '카테고리별 충족률', 1, 725.1),
        StatisticsTileSpec(
          'B2',
          '부족 · 과잉',
          2,
          758.6,
          segments: ['부족 순', '과잉 순'],
          showsOrderChip: false,
        ),
      ]),
      StatisticsTileRow(351, [
        StatisticsTileSpec(
          'B3',
          '주요 재화 변화',
          3,
          1455.2,
          segments: ['스냅샷 6회', '4주', '전체'],
        ),
      ]),
    ],
    StatisticsMode.plan => const [
      StatisticsTileRow(358, [
        StatisticsTileSpec(
          'C1',
          '필요량 vs 보유',
          1,
          749.8,
          segments: ['부족 큰 순', '페이즈 순'],
          showsOrderChip: false,
        ),
        StatisticsTileSpec('C2', '병목 매트릭스', 1, 749.8),
      ]),
      StatisticsTileRow(327, [
        StatisticsTileSpec('C3', '페이즈별 누적 부족', 2, 777.0),
        StatisticsTileSpec('C4', '학생별 목표 진행', 2, 711.6),
      ]),
      StatisticsTileRow(313, [
        StatisticsTileSpec('C5', '미계획 학생', 3, 1448.5),
      ]),
    ],
  };

  /// 오른쪽 아래 ghost · primary 버튼(시안 글자 중 구간에 묶이지 않은 부분).
  (StatisticsEvidenceAction, StatisticsEvidenceAction) get evidenceActions =>
      switch (this) {
        StatisticsMode.students => (
          const StatisticsEvidenceAction('학생 탭에서 보기'),
          const StatisticsEvidenceAction('이 구간 학생을 계획에 추가'),
        ),
        StatisticsMode.inventory => (
          const StatisticsEvidenceAction('인벤토리 · 티어별 충족률'),
          const StatisticsEvidenceAction(
            '인벤토리 · 부족 위험에서 보기',
            '해당 행 선택 · 획득처',
          ),
        ),
        StatisticsMode.plan => (
          const StatisticsEvidenceAction(
            '인벤토리 · 부족 위험에서 보기',
            '해당 행 선택 · 획득처',
          ),
          const StatisticsEvidenceAction('계획 만들기 3 · 단계 순서'),
        ),
      };
}

/// 타일 높이 비율: 지금 viewport 폭 / 시안 viewport 폭. 기준 viewport에서 1이다.
double statisticsTileScale(double viewportWidth) =>
    viewportWidth / StatisticsMetrics.referenceViewportWidth;

/// 한 줄 안 타일 자리(줄 자리 왼쪽 기준 x · 폭).
///
/// 타일은 80° 평행사변형이라 이웃 타일의 사선 변 사이를 가로 [StatisticsMetrics.tileGap]만큼 띄우면 bounding box가
/// 사선 깊이 − 간격만큼 겹친다. 그래서 줄 폭 + (n−1)(깊이 − 간격)을 시안 폭 비율로 나눈다. 기준 viewport에서는
/// 시안 rect와 같다(예: A1 791.4 · A2 695.5, 두 rect 사이 겹침 36.8).
List<({double left, double width})> statisticsTileSlots({
  required double rowWidth,
  required double height,
  required List<double> widths,
}) {
  if (widths.isEmpty) return const [];
  final depth = diagonalCutDepth(height);
  final total = widths.fold<double>(0, (sum, width) => sum + width);
  final available =
      rowWidth + (widths.length - 1) * (depth - StatisticsMetrics.tileGap);
  final slots = <({double left, double width})>[];
  var left = 0.0;
  for (final width in widths) {
    final slotWidth = total <= 0 ? 0.0 : available * width / total;
    slots.add((left: left, width: slotWidth));
    left += slotWidth - depth + StatisticsMetrics.tileGap;
  }
  return slots;
}
