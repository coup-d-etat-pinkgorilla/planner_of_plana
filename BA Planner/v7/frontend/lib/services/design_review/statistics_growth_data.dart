// 통계 "학생 성장" 시안 숫자 데이터(FE7-b, 시안 Stats-Growth). mockdemo에서 `test/statistics_growth_fixture.dart`에서 옮겼다.
//
// 테스트 fixture(`test/statistics_growth_fixture.dart`)와 검수 시나리오 Mock(`mock_design_review_scenario.dart`)이 같이 쓴다.
// 시안 숫자를 재현해 사용자가 캔버스와 같은 숫자로 비교하게 한다(워크플로 불변식 "mock fixture"):
// 보유 128 / 학생 목록 170, A1 10% 구간 3 · 5 · 9 · 12 · 15 · 18 · 22 · 19 · 14 · 11명(60~70% 구간 22명),
// 평균 육성도 63.4%, 최대 레벨 64명, 계획 등록 9명(60~70% 구간 안 2명).
// 시안끼리 맞지 않는 숫자는 재현하지 않는다(status FE7-b 종료 기록): 완전 육성 22명은 90~100% 구간 11명보다 많아 8명,
// A2 막대(시안 6행 · 평균 60.5%)는 A1 평균 63.4%와 맞지 않아 이 학생 값에서 나온 값이다.
// 학생 id는 번들 학생 목록(`assets/student_catalog.json`)을 id 순으로 늘어놓은 앞 170명이고, 그중 앞 128명이 보유다.
// 값은 FD-028 (a) 식으로 구간 · 평균이 맞게 골랐다(애장품이 없는 학생은 애장품 열이 null). 전용무기는 ★5 학생만 1 이상이다.
import '../repository_service.dart';

/// 보유 학생 한 명: id, 레벨, EX, 스킬 1~3, 장비 1~3 티어, 애장품 티어(없는 학생은 null), 성급, 전용무기 ★.
typedef StatisticsGrowthFixtureRow = (
  String id,
  int level,
  int ex,
  int skill1,
  int skill2,
  int skill3,
  int equip1,
  int equip2,
  int equip3,
  int? equip4,
  int star,
  int weapon,
);

const statisticsGrowthFixtureOwned = <StatisticsGrowthFixtureRow>[
  ('airi', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('airi_band', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('akane', 56, 3, 8, 6, 3, 4, 5, 5, null, 2, 0),
  ('akane_bunny_girl', 90, 5, 10, 10, 10, 10, 10, 10, null, 5, 4),
  ('akane_school_uniform', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('akari', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('akari_new_year', 47, 2, 4, 4, 4, 4, 4, 4, null, 2, 0),
  ('ako', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('ako_dress', 90, 5, 10, 10, 10, 10, 10, 10, null, 5, 4),
  ('aoba', 56, 3, 8, 6, 3, 4, 5, 5, null, 2, 0),
  ('aris', 90, 5, 10, 10, 10, 10, 10, 10, 2, 5, 1),
  ('aris_battle', 90, 5, 10, 10, 10, 10, 10, 10, null, 5, 4),
  ('aris_maid', 47, 1, 9, 1, 3, 4, 4, 4, 1, 2, 0),
  ('aru', 57, 3, 5, 4, 4, 5, 5, 5, 1, 2, 0),
  ('aru_dress', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('aru_new_year', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('asuna', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('asuna_bunny_girl', 66, 4, 9, 6, 5, 6, 6, 6, 1, 2, 0),
  ('asuna_school_uniform', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('atsuko', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('atsuko_swimsuit', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('ayane', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('ayane_swimsuit', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('azusa', 66, 4, 10, 5, 5, 6, 6, 6, null, 2, 0),
  ('azusa_swimsuit', 30, 1, 2, 1, 1, 1, 2, 2, null, 1, 0),
  ('cherino', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('cherino_hot_springs', 90, 4, 10, 8, 7, 8, 8, 8, 2, 3, 0),
  ('chiaki', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('chihiro', 56, 3, 8, 4, 4, 5, 5, 5, null, 2, 0),
  ('chinatsu', 90, 5, 10, 8, 8, 10, 10, 9, 2, 4, 0),
  ('chinatsu_hot_springs', 56, 3, 8, 6, 3, 4, 5, 5, null, 2, 0),
  ('chise', 66, 4, 9, 6, 5, 7, 6, 5, 1, 2, 0),
  ('chise_swimsuit', 90, 5, 10, 8, 8, 10, 10, 9, 2, 4, 0),
  ('eimi', 90, 4, 10, 8, 7, 8, 8, 8, 2, 3, 0),
  ('eimi_battle', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('eimi_swimsuit', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('eri', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('erika', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('fubuki', 90, 5, 10, 10, 10, 10, 10, 10, null, 5, 4),
  ('fubuki_swimsuit', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('fuuka', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('fuuka_new_year', 37, 2, 3, 3, 2, 4, 2, 3, null, 1, 0),
  ('fuyu', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('hanae', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('hanae_christmas', 90, 5, 10, 8, 8, 10, 10, 9, 2, 4, 0),
  ('hanako', 90, 5, 10, 10, 10, 10, 10, 10, 2, 5, 1),
  ('hanako_swimsuit', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('hare', 90, 5, 10, 8, 8, 10, 10, 9, 2, 4, 0),
  ('hare_camping', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('haruka', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('haruka_dress', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('haruka_new_year', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('haruna', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('haruna_new_year', 47, 2, 4, 4, 4, 4, 4, 4, null, 2, 0),
  ('haruna_sportswear', 90, 4, 10, 8, 7, 8, 8, 8, 2, 3, 0),
  ('hasumi', 72, 3, 9, 6, 6, 7, 7, 7, 2, 3, 0),
  ('hasumi_sportswear', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('hasumi_swimsuit', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('hatsune_miku', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('hibiki', 90, 4, 10, 8, 7, 8, 8, 8, 2, 3, 0),
  ('hibiki_cheerleader', 47, 2, 4, 4, 4, 4, 4, 4, null, 2, 0),
  ('hifumi', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('hifumi_swimsuit', 66, 4, 9, 6, 5, 6, 6, 6, 1, 2, 0),
  ('hikari', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('himari', 90, 5, 10, 9, 10, 10, 10, 10, null, 5, 4),
  ('himari_battle', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('hina', 90, 4, 10, 8, 7, 8, 8, 8, 2, 3, 0),
  ('hina_dress', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('hina_swimsuit', 90, 5, 10, 8, 8, 10, 10, 9, 2, 4, 0),
  ('hinata', 90, 4, 10, 8, 7, 8, 8, 8, 2, 3, 0),
  ('hinata_swimsuit', 90, 5, 10, 10, 10, 10, 10, 10, null, 5, 4),
  ('hiyori', 56, 3, 8, 4, 4, 5, 5, 5, null, 2, 0),
  ('hiyori_swimsuit', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('hoshino', 29, 1, 5, 1, 1, 1, 2, 2, 0, 1, 0),
  ('hoshino_battle', 66, 4, 10, 5, 5, 6, 6, 6, null, 2, 0),
  ('hoshino_swimsuit', 56, 3, 8, 6, 3, 4, 5, 5, null, 2, 0),
  ('ibuki', 47, 2, 4, 4, 4, 4, 4, 4, null, 2, 0),
  ('ichika', 66, 4, 10, 5, 5, 6, 6, 6, null, 2, 0),
  ('ichika_swimsuit', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('iori', 47, 2, 4, 4, 4, 4, 4, 4, null, 2, 0),
  ('iori_swimsuit', 90, 5, 10, 10, 10, 10, 10, 10, 2, 5, 4),
  ('iroha', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('izumi', 72, 3, 9, 6, 6, 7, 7, 7, 2, 3, 0),
  ('izumi_new_year', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('izumi_swimsuit', 90, 5, 10, 9, 10, 10, 10, 10, 2, 5, 4),
  ('izuna', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('izuna_swimsuit', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('junko', 90, 4, 10, 8, 7, 8, 8, 8, 2, 3, 0),
  ('junko_new_year', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('juri', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('juri_part_timer', 37, 2, 3, 3, 2, 4, 2, 3, null, 1, 0),
  ('kaede', 48, 1, 5, 5, 3, 4, 4, 4, 1, 2, 0),
  ('kaho', 57, 3, 5, 4, 4, 5, 5, 5, 1, 2, 0),
  ('kanna', 56, 3, 8, 4, 4, 5, 5, 5, null, 2, 0),
  ('kanna_swimsuit', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('kanoe', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('karin', 90, 5, 10, 10, 10, 10, 10, 10, null, 5, 4),
  ('karin_bunny_girl', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('karin_school_uniform', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('kasumi', 82, 5, 10, 5, 7, 8, 8, 8, null, 4, 0),
  ('kayoko', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('kayoko_dress', 90, 5, 9, 9, 9, 9, 9, 9, null, 5, 0),
  ('kayoko_new_year', 90, 5, 10, 9, 10, 10, 10, 10, null, 5, 4),
  ('kazusa', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('kazusa_band', 66, 4, 9, 6, 5, 6, 6, 6, 1, 2, 0),
  ('kei', 47, 2, 4, 4, 4, 4, 4, 4, null, 2, 0),
  ('kikyou', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('kikyou_swimsuit', 56, 3, 8, 6, 3, 4, 5, 5, null, 2, 0),
  ('kirara', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('kirino', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('kirino_swimsuit', 56, 3, 8, 4, 4, 5, 5, 5, null, 2, 0),
  ('kisaki', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('kisaki_swimsuit', 37, 2, 3, 3, 2, 4, 2, 3, null, 1, 0),
  ('koharu', 66, 4, 9, 6, 5, 6, 6, 6, null, 2, 0),
  ('koharu_swimsuit', 82, 5, 10, 5, 7, 8, 8, 8, null, 4, 0),
  ('kokona', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('konoka', 37, 2, 3, 3, 2, 4, 2, 3, null, 1, 0),
  ('kotama', 30, 1, 2, 1, 1, 1, 2, 2, null, 1, 0),
  ('kotama_camping', 90, 5, 10, 9, 7, 8, 8, 8, null, 3, 0),
  ('kotori', 72, 3, 9, 5, 6, 8, 7, 7, 2, 3, 0),
  ('kotori_cheerleader', 73, 4, 10, 8, 6, 8, 7, 7, null, 3, 0),
  ('koyuki', 90, 5, 10, 8, 8, 10, 10, 9, 2, 4, 0),
  ('koyuki_pajama', 37, 2, 3, 3, 2, 4, 2, 3, null, 1, 0),
  ('kurumi', 47, 2, 4, 4, 4, 4, 4, 4, null, 2, 0),
  ('maki', 90, 5, 9, 9, 9, 10, 10, 10, null, 5, 2),
  ('maki_camping', 56, 3, 8, 4, 4, 5, 5, 5, null, 2, 0),
  ('makoto', 90, 5, 10, 10, 10, 10, 10, 10, null, 5, 4),
  ('mari', 72, 3, 9, 5, 6, 8, 7, 7, 2, 3, 0),
];

/// 보유하지 않은 학생 목록 42명.
const statisticsGrowthFixtureUnownedIds = <String>[
  'mari_idol', 'mari_sportswear', 'marina', 'marina_qipao', 'mashiro',
  'mashiro_swimsuit', 'megu', 'meru', 'michiru', 'michiru_dress', 'midori',
  'midori_maid', 'mika', 'mika_swimsuit', 'mimori', 'mimori_swimsuit', 'mina',
  'mine', 'mine_idol', 'minori', 'misaka_mikoto', 'misaki', 'misaki_swimsuit',
  'miyako', 'miyako_swimsuit', 'miyo', 'miyu', 'miyu_swimsuit', 'moe',
  'moe_swimsuit', 'momiji', 'momoi', 'momoi_maid', 'mutsuki', 'mutsuki_dress',
  'mutsuki_new_year', 'nagisa', 'nagisa_swimsuit', 'nagusa', 'nagusa_swimsuit',
  'natsu', 'natsu_band',
];

/// 번들 학생 목록에서 애장품이 있는 학생(`has_favorite_item`).
const statisticsGrowthFixtureFavoriteItemIds = <String>[
  'aris', 'aris_maid', 'aru', 'asuna_bunny_girl', 'cherino_hot_springs',
  'chinatsu', 'chise', 'chise_swimsuit', 'eimi', 'hanae_christmas', 'hanako',
  'hare', 'haruna_sportswear', 'hasumi', 'hibiki', 'hifumi_swimsuit', 'hina',
  'hina_swimsuit', 'hinata', 'hoshino', 'iori_swimsuit', 'izumi',
  'izumi_swimsuit', 'junko', 'kaede', 'kaho', 'kazusa_band', 'kotori',
  'koyuki', 'mari', 'mashiro', 'michiru', 'midori', 'mimori', 'misaki',
  'miyako', 'miyu', 'momiji', 'momoi',
];

/// 계획(사용자 목표)에 등록된 보유 학생 9명. eimi · hina는 육성도 60~70% 구간이다(시안 구간 요약 "계획 등록 2명").
const statisticsGrowthFixturePlannedIds = <String>[
  'airi',
  'akane',
  'aris',
  'aru',
  'eimi',
  'hina',
  'hoshino',
  'kazusa',
  'koyuki',
];

List<String> get statisticsGrowthFixtureCatalogIds => [
  for (final row in statisticsGrowthFixtureOwned) row.$1,
  ...statisticsGrowthFixtureUnownedIds,
];

/// 확정 학생 wire(계정 상태 `students`).
List<Map<String, dynamic>> statisticsGrowthFixtureStudentsWire() => [
  for (final row in statisticsGrowthFixtureOwned)
    {
      'version': 1,
      'student_id': row.$1,
      'values': <String, dynamic>{
        'level': row.$2,
        'ex_skill': row.$3,
        'skill1': row.$4,
        'skill2': row.$5,
        'skill3': row.$6,
        'equip1': 'T${row.$7}',
        'equip2': 'T${row.$8}',
        'equip3': 'T${row.$9}',
        'equip4': row.$10 == null ? 'love_locked' : 'T${row.$10}',
        'student_star': row.$11,
        'weapon_star': row.$12,
      },
    },
];

/// 사용자 목표 wire(계정 상태 `goals`).
Map<String, dynamic> statisticsGrowthFixtureGoalsWire() => {
  'version': 1,
  'goals': [
    for (final id in statisticsGrowthFixturePlannedIds)
      {'student_id': id, 'target_level': 90},
  ],
};

/// 계정 상태. [inventory]가 없으면 빈 인벤토리다.
RepositoryState statisticsGrowthFixtureState({
  String profileId = '0123456789abcdef01234567',
  int revision = 1,
  Map<String, dynamic>? inventory,
}) => RepositoryState.fromWire({
  'profile_id': profileId,
  'revision': revision,
  'students': statisticsGrowthFixtureStudentsWire(),
  'inventory': inventory ?? {'version': 1, 'entries': <Object>[]},
  'goals': statisticsGrowthFixtureGoalsWire(),
});
