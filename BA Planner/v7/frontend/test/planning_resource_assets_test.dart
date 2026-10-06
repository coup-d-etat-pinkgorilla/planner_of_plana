import 'package:ba_planner_v7/ui/models/planning_resource_assets.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('canonical resource IDs resolve to decodable bundled images', () async {
    final samples = [
      ('tech_notes', 'Item_Icon_SkillBook_Abydos_0'),
      ('tactical_bd', 'Item_Icon_Material_ExSkill_Trinity_3'),
      ('equipment', 'Equipment_Icon_Shoes_Tier10'),
      ('student_eleph', 'Item_Icon_SecretStone_ayane'),
      ('oopart', 'Item_Icon_Material_Nebra_0'),
      ('present', 'Item_Icon_Favor_0'),
      ('activity_report', 'Item_Icon_ExpItem_0'),
      ('activity_report', 'Item_Icon_ExpItem_1'),
      ('activity_report', 'Item_Icon_ExpItem_2'),
      ('activity_report', 'Item_Icon_ExpItem_3'),
      ('workbook', 'Item_Icon_WorkBook_PotentialMaxHP'),
      ('workbook', 'Item_Icon_WorkBook_PotentialAttack'),
      ('workbook', 'Item_Icon_WorkBook_PotentialHealPower'),
    ];
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final sample in samples) {
      final path = planningResourceIconAsset(
        category: sample.$1,
        itemId: sample.$2,
      )!;
      expect(manifest.listAssets(), contains(path), reason: sample.$2);
      final bytes = await rootBundle.load(path);
      final image = await decodeImageFromList(bytes.buffer.asUint8List());
      expect(image.width, greaterThan(16));
      expect(image.height, greaterThan(16));
      image.dispose();
    }
    expect(
      planningResourceIconAsset(category: 'unknown', itemId: 'missing'),
      isNull,
    );
  });
}
