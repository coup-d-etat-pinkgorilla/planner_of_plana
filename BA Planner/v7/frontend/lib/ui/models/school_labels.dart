// 학교 표시 이름 · 엠블럼 asset 공용 맵(FE6-e, FE6-c 발견 3 CF 결정).
//
// 같은 학교가 두 꼴로 들어온다: 인벤토리 카탈로그 school 값(FB-3, `RedWinter`·`Wildhunt`)과 학생 카탈로그 school
// 값(`red winter`·`wild hunt`, 공백 · 소문자). [schoolKey]가 둘을 같은 키(소문자, 공백 · `_` · `-` 없음)로 만든다.
// 표시 이름 · 엠블럼은 값 검증이 아니라 화면 표시이므로 모르는 값은 그대로(이름) · null(엠블럼)이다.
import '../kit/game_assets.dart';

/// 학교 값의 정규화 키(소문자, 공백 · `_` · `-` 제거). `RedWinter`와 `red winter`는 둘 다 `redwinter`다.
String schoolKey(String school) =>
    school.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

/// 학교 화면 이름. 모르는 값은 받은 그대로다.
String schoolLabel(String school) => switch (schoolKey(school)) {
  'hyakkiyako' => '백귀야행',
  'redwinter' => '붉은겨울',
  'trinity' => '트리니티',
  'gehenna' => '게헨나',
  'abydos' => '아비도스',
  'millennium' => '밀레니엄',
  'arius' => '아리우스',
  'shanhaijing' => '산해경',
  'valkyrie' => '발키리',
  'highlander' => '하이랜더',
  'wildhunt' => '와일드헌트',
  'srt' => 'SRT',
  'tokiwadai' => '토키와다이',
  'sakugawa' => '사쿠가와',
  'etc' => '기타',
  _ => school,
};

/// 학교 엠블럼 그림 이름(`School_Icon_<name>.png`의 `<name>`). 맞는 그림이 없으면 null.
String? schoolEmblemName(String? school) => switch (school == null
    ? null
    : schoolKey(school)) {
  'abydos' => 'ABYDOS',
  'arius' => 'Arius',
  'gehenna' => 'GEHENNA',
  'highlander' => 'HIGHLANDER',
  'hyakkiyako' => 'HYAKKIYAKO',
  'millennium' => 'MILLENNIUM',
  'redwinter' => 'REDWINTER',
  'sakugawa' => 'SAKUGAWA',
  'shanhaijing' => 'SHANHAIJING',
  'srt' => 'SRT',
  'tokiwadai' => 'Tokiwadai',
  'trinity' => 'TRINITY',
  'valkyrie' => 'VALKYRIE',
  'wildhunt' => 'WILDHUNT',
  'etc' => 'ETC',
  _ => null,
};

/// 학교 엠블럼 asset 경로. 맞는 그림이 없으면 null.
String? schoolEmblemAsset(String? school) {
  final name = schoolEmblemName(school);
  return name == null ? null : GameAssets.schoolLogo(name);
}
