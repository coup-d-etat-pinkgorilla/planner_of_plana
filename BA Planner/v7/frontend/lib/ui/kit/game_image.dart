// 게임 그림 한 장을 그리는 공용 위젯과 그림 출처 (F5a, FD-181).
//
// 화면이 쓰는 게임 그림(학생 초상 · 엘레프 · 아이템 · 장비 · 학교 로고 · 배경)은 모두 이 파일을 거쳐 읽는다.
// 그림의 키는 지금의 `assets/...` 상대 경로([GameAssets])이고, 키를 그림으로 바꾸는 것은 [GameArtSource]다.
// 앱 루트의 [GameArtScope]가 출처를 정한다. 기본 출처는 지금과 같은 번들 자산이라 화면은 바뀌지 않는다.
// 배포본은 게임 그림을 싣지 않고 첫 실행 때 사용자 설치본에서 가져온다(FD-181). 그 출처는 F5b가 이 자리에 붙인다.
// 출처에 그림이 없거나 읽기에 실패하면 같은 크기의 빈 그림 자리([GameImagePlaceholder])를 그리고 예외를 내지
// 않는다. 이름 · 수치는 그림 밖에 있으므로 그대로 보인다.
import 'package:flutter/material.dart';

import 'game_assets.dart';

/// 그림 키의 분류(FD-181, F5a status 분류 표).
enum GameArtKind {
  /// 게임 그림. 배포본에서 빼고 사용자 설치본에서 가져온다.
  gameArt,

  /// 출처 확인이 필요한 그림(홈 메뉴 · 정사각 배경 · studio 그림). 확인 뒤 같은 규칙.
  sourceCheck,

  /// 게임 그림이 아니다.
  other,
}

/// 게임 그림 폴더(FD-181 대상).
const gameArtDirectories = [
  'assets/student_portraits/',
  'assets/student_elephs/',
  '${GameAssets.itemIconDirectory}/',
  'assets/equipment_icons/',
];

/// 출처 확인이 필요한 그림 폴더.
const gameArtSourceCheckDirectories = [
  'assets/home_menu/',
  'assets/item_backgrounds/',
  'assets/student_bond_backgrounds/',
  'assets/studio_features/',
];

/// [key]가 어느 그림 폴더에 있는가.
GameArtKind gameArtKindOf(String key) {
  if (gameArtDirectories.any(key.startsWith)) return GameArtKind.gameArt;
  if (gameArtSourceCheckDirectories.any(key.startsWith)) {
    return GameArtKind.sourceCheck;
  }
  return GameArtKind.other;
}

/// 그림 키 → 그림.
abstract class GameArtSource {
  const GameArtSource();

  /// [key]의 그림. 이 출처에 그림이 없으면 `null`(빈 그림 자리로 그린다).
  ImageProvider? resolve(String key);
}

/// 지금과 같은 번들 자산 출처(기본).
class BundledGameArtSource extends GameArtSource {
  const BundledGameArtSource();

  @override
  ImageProvider resolve(String key) => GameArtAssetImage(key);
}

/// 아래 위젯들이 읽을 그림 출처를 정한다(앱 루트 · 테스트에서 주입). 없으면 [BundledGameArtSource].
class GameArtScope extends InheritedWidget {
  const GameArtScope({super.key, required this.source, required super.child});

  final GameArtSource source;

  /// 조상에 출처가 없을 때 쓰는 출처.
  static const fallback = BundledGameArtSource();

  /// 빌드 중에 읽는다(출처가 바뀌면 다시 그린다).
  static GameArtSource of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameArtScope>()?.source ??
      fallback;

  /// 빌드 밖(미리 읽기)에서 읽는다(의존성을 만들지 않는다).
  static GameArtSource read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameArtScope>()?.source ?? fallback;

  @override
  bool updateShouldNotify(GameArtScope oldWidget) =>
      !identical(oldWidget.source, source);
}

/// 출처에 그림이 없을 때 [GameImage.errorBuilder]에 넘기는 오류.
class GameArtMissing implements Exception {
  const GameArtMissing(this.key);

  final String key;

  @override
  String toString() => 'GameArtMissing($key)';
}

/// 게임 그림 한 장. [Image.asset]과 같은 자리 · 같은 인자로 쓴다.
///
/// 출처에 그림이 없거나 읽기에 실패하면 [errorBuilder]를, 없으면 같은 크기의 [GameImagePlaceholder]를 그린다.
class GameImage extends StatelessWidget {
  const GameImage(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
  });

  /// 그림 키(지금의 `assets/...` 경로).
  final String asset;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  Widget _placeholder(BuildContext context, Object error, StackTrace? stack) =>
      GameImagePlaceholder(width: width, height: height);

  @override
  Widget build(BuildContext context) {
    final image = GameArtScope.of(context).resolve(asset);
    final errorBuilder = this.errorBuilder ?? _placeholder;
    if (image == null) {
      return errorBuilder(context, GameArtMissing(asset), null);
    }
    return Image(
      image: image,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
  }
}

/// 그림이 없을 때의 빈 그림 자리(임시 모양: 같은 크기의 투명한 자리).
///
/// 최종 모양은 F1 시안 `W-Missing-Art`를 따른다(F5b/F3).
class GameImagePlaceholder extends StatelessWidget {
  const GameImagePlaceholder({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}

/// 그림 파일이 없을 때 오류를 조용히 받는 [AssetImage](기존 `ItemIconAssetImage`, FE2-d).
///
/// [Image.errorBuilder]는 위젯이 스트림을 듣는 동안에만 오류를 받는다. 읽기가 끝나기 전에 위젯이 트리에서
/// 빠지면(목록 다시 그리기·정렬) 듣는 곳이 없는 스트림이 버려지고, 늦게 온 "파일 없음" 오류가 `FlutterError`로
/// 올라간다(위젯 테스트에서는 실패). 첫 결과(그림 또는 오류)가 올 때까지만 리스너 하나를 붙여 두어 그 경우에도
/// 조용히 끝낸다. 읽기·캐시 key·그리기는 [AssetImage]와 같다.
class GameArtAssetImage extends AssetImage {
  const GameArtAssetImage(super.assetName);

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    AssetBundleImageKey key,
    ImageErrorListener handleError,
  ) {
    super.resolveStreamForKey(configuration, stream, key, handleError);
    final completer = stream.completer;
    // 캐시에서 읽는 중인 그림에만 붙인다. 이미 다 읽힌(또는 이미 실패한) completer에 붙이면 리스너가 그 자리에서
    // 불려 바로 떨어지고, 그때 듣는 곳이 없으면 completer가 버려진다.
    final status = PaintingBinding.instance.imageCache.statusForKey(key);
    if (completer == null || !status.pending) return;
    late final ImageStreamListener listener;
    listener = ImageStreamListener((image, _) {
      image.dispose();
      completer.removeListener(listener);
    }, onError: (_, _) => completer.removeListener(listener));
    completer.addListener(listener);
  }
}
