// 게임 이미지 asset 경로 (FE2-d).
//
// 아이템 아이콘·아이템 배경·장비 아이콘·학교 로고·학생 초상 경로를 한곳에 모은다. 각 위젯에 흩어져 있던
// 문자열과 같은 값이다(렌더는 바뀌지 않는다).
// 게임 이미지는 저장소에 넣지 않는다. 배포본은 첫 실행 때 사용자 설치본에서 추출하므로, 파일이 없을 수
// 있다. 이 경로는 그림 키이고, 그림은 `game_image.dart`의 공용 출처(`GameImage`, F5a)에서 읽는다. 그림이
// 없으면 빈 그림 자리로 그리고 예외를 내지 않는다.

/// 게임 이미지 asset 경로.
abstract final class GameAssets {
  /// 아이템 배경(시안 `.pt` 배경). 기본·보라·노랑 세 가지다.
  static const itemBackgroundBasic = 'assets/item_backgrounds/square.png';
  static const itemBackgroundPurple = 'assets/item_backgrounds/square_purple.png';
  static const itemBackgroundYellow = 'assets/item_backgrounds/square_yellow.png';

  /// 작은 학생 초상 뒤 사각 바탕. 시안은 아이템 기본 배경과 같은 그림을 쓴다(W-Data "부족 상위 행").
  static const portraitBackground = itemBackgroundBasic;

  /// 크레딧 아이콘.
  static const creditIcon = 'assets/item_icons/currency/Currency_Icon_Gold.png';

  /// 계획 견본이 쓰는 장비 T10 아이콘.
  static const equipmentHatT10 = 'assets/equipment_icons/hat_t10.png';
  static const equipmentHairpinT10 = 'assets/equipment_icons/hairpin_t10.png';
  static const equipmentWatchT10 = 'assets/equipment_icons/watch_t10.png';

  static const itemIconDirectory = 'assets/item_icons';
  static const equipmentIconDirectory = 'assets/item_icons/equipment';

  /// `assets/item_icons/<category>/<fileStem>.png`(예: `ooparts`, `Item_Icon_Material_Nebra_2`).
  static String itemIcon(String category, String fileStem) =>
      '$itemIconDirectory/$category/$fileStem.png';

  /// 장비 아이콘(`Equipment_Icon_<type>_Tier<tier>.png`). [piece]면 설계도(`_Piece`).
  static String equipmentIcon(String type, int tier, {bool piece = false}) =>
      '$equipmentIconDirectory/Equipment_Icon_${type}_Tier$tier'
      '${piece ? '_Piece' : ''}.png';

  /// 학교 로고(`School_Icon_<name>.png`).
  static String schoolLogo(String name) =>
      '$itemIconDirectory/school_logo/School_Icon_$name.png';

  /// 학생 엘레프(`assets/student_elephs/<id>.png`).
  static String studentEleph(String itemId) => 'assets/student_elephs/$itemId.png';

  /// 학생 초상(`assets/student_portraits/<id>.png`).
  static String studentPortrait(String studentId) =>
      'assets/student_portraits/$studentId.png';
}

/// 아이템 배경 종류(시안 `.pt` 배경 세 가지).
enum ItemBackground {
  basic(GameAssets.itemBackgroundBasic),
  purple(GameAssets.itemBackgroundPurple),
  yellow(GameAssets.itemBackgroundYellow);

  const ItemBackground(this.asset);

  final String asset;
}
