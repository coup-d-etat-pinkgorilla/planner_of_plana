// FE6-e 학교 표시 이름 · 엠블럼 공용 맵(`ui/models/school_labels.dart`) 정규화 테스트. 인벤토리 카탈로그 값(`RedWinter`·
// `Wildhunt`)과 학생 카탈로그 값(`red winter`·`wild hunt`)이 같은 키 · 이름 · 그림으로 모인다.
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/kit/game_assets.dart';
import 'package:ba_planner_v7/ui/models/school_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('카탈로그 꼴과 학생 꼴이 같은 키가 된다', () {
    for (final (catalog, student) in const [
      ('RedWinter', 'red winter'),
      ('Wildhunt', 'wild hunt'),
      ('Millennium', 'millennium'),
      ('Hyakkiyako', 'hyakkiyako'),
      ('SRT', 'srt'),
    ]) {
      expect(schoolKey(catalog), schoolKey(student), reason: catalog);
      expect(schoolLabel(catalog), schoolLabel(student), reason: catalog);
      expect(schoolEmblemAsset(catalog), schoolEmblemAsset(student), reason: catalog);
    }
    expect(schoolKey(' Red_Winter '), 'redwinter');
    expect(schoolKey('Red-Winter'), 'redwinter');
  });

  test('표시 이름: 아는 학교 15곳, 모르는 값은 그대로', () {
    expect(schoolLabel('RedWinter'), '붉은겨울');
    expect(schoolLabel('Wildhunt'), '와일드헌트');
    expect(schoolLabel('Shanhaijing'), '산해경');
    expect(schoolLabel('Highlander'), '하이랜더');
    expect(schoolLabel('etc'), '기타');
    expect(schoolLabel('Unknown School'), 'Unknown School');
    // 인벤토리 쪽 이름 함수는 공용 맵을 쓴다.
    expect(inventorySchoolLabel('red winter'), '붉은겨울');
  });

  test('엠블럼: 그림 이름 대소문자는 asset 그대로, 모르면 null', () {
    expect(schoolEmblemAsset('RedWinter'), GameAssets.schoolLogo('REDWINTER'));
    expect(schoolEmblemAsset('wild hunt'), GameAssets.schoolLogo('WILDHUNT'));
    expect(schoolEmblemAsset('Arius'), GameAssets.schoolLogo('Arius'));
    expect(schoolEmblemAsset('tokiwadai'), GameAssets.schoolLogo('Tokiwadai'));
    expect(schoolEmblemAsset('ETC'), GameAssets.schoolLogo('ETC'));
    expect(schoolEmblemAsset('Unknown'), isNull);
    expect(schoolEmblemAsset(null), isNull);
  });
}
