// 첫 실행 ① "폴더 고르기"(F3b). 기본은 기존 의존성 `file_selector`의 폴더 대화상자다. 시험은 가짜를 넣는다
// (실제 게임 설치 폴더를 읽지 않는다 — 고른 경로는 `assets.prepare.game_dir.set`이 검사한다).
import 'package:file_selector/file_selector.dart';

/// 게임 설치 폴더를 고른다(취소면 null).
abstract interface class FirstRunFolderPicker {
  Future<String?> pick({String? initialDirectory});
}

/// 운영체제 폴더 대화상자.
class NativeFirstRunFolderPicker implements FirstRunFolderPicker {
  const NativeFirstRunFolderPicker();

  @override
  Future<String?> pick({String? initialDirectory}) async {
    final path = await getDirectoryPath(initialDirectory: initialDirectory);
    return path == null || path.isEmpty ? null : path;
  }
}
