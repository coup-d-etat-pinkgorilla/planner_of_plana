// 첫 실행 ①~③(F3b)의 판단 규칙과 문구표. 화면은 `first_run_modal.dart`가 그린다.
//
// - 언제 뜨나([decideFirstRun]): 새 저장소 없이 지금 상태(계정 목록 · `assets.prepare.status`의 cache.state)에서만 판단한다.
//   계정이 없으면 ①부터, 계정이 있고 캐시가 missing · stale · invalid면 ②만. 나머지는 띄우지 않는다.
// - 진행 수(contracts/asset-preparation-v1): 단위는 번들이다. total이 null이면 분모 · % · 남은 시간을 숨긴다. 작업 전체의
//   고정 분모(예: 1,330 · 시안 예시 2,400)는 만들지 않는다. 결과 수의 null은 '—'(0으로 바꾸지 않음).
// - 알파-1(D-ALPHA-SPLIT)은 인식 캐시만 준비한다: 단계 줄은 아이템 아이콘(icons) · 스캔용 그림(sprites) · 글꼴(fonts)
//   셋이다. 시안의 학생 초상 · 엘레프 줄(화면 그림, 알파-2 F5b)은 그리지 않는다.
import 'package:flutter/widgets.dart';

import '../../services/asset_preparation_service.dart';
import '../../services/repository_service.dart';

/// 첫 실행 모달을 켜는 방식(사용자 결정 2026-10-21: 기본은 끄고 `main.dart`가 실제 앱만 켠다).
enum FirstRunLaunch {
  /// 띄우지 않는다(시험 · golden 기본).
  off,

  /// [decideFirstRun] 규칙대로.
  auto,

  /// 계정이 있어도 ①부터(검수용 `--dart-define=BA_PLANNER_FIRST_RUN=full`).
  full;

  /// `BA_PLANNER_FIRST_RUN` 값(`off` · `full`, 그 밖은 [auto]).
  static FirstRunLaunch fromDefine(String value) => switch (value.trim()) {
    'off' => FirstRunLaunch.off,
    'full' => FirstRunLaunch.full,
    _ => FirstRunLaunch.auto,
  };
}

/// 모달이 어디서 시작하는가.
enum FirstRunEntry {
  /// ① 게임 설치 찾기 → ② 이미지 준비 → ③ 계정 만들기.
  full,

  /// ②만(계정은 있고 준비가 필요할 때 — 시안 "변형 · 게임 업데이트 뒤 앱 시작 때 ②만").
  imagesOnly,
}

/// 모달 안의 단계.
enum FirstRunStep { game, images, account }

/// ③ "만들고 튜토리얼 시작" 뒤에 부르는 자리(F3c 입력). [account]는 방금 만들고 고른 첫 계정이다.
typedef FirstRunTutorialStarter =
    void Function(BuildContext context, RepositoryProfile account);

/// ②만을 띄우는 캐시 상태.
const firstRunImagesOnlyCacheStates = {
  AssetCacheState.missing,
  AssetCacheState.stale,
  AssetCacheState.invalid,
};

/// 첫 실행 모달을 띄울지 정한다. null = 띄우지 않음.
///
/// [hasAccount]는 계정 목록을 읽은 결과다(읽지 못했으면 이 함수를 부르지 않는다). [cache]는 준비 status를 읽지 못했으면
/// null이다.
FirstRunEntry? decideFirstRun({
  required FirstRunLaunch launch,
  required bool hasAccount,
  required AssetCacheState? cache,
}) {
  switch (launch) {
    case FirstRunLaunch.off:
      return null;
    case FirstRunLaunch.full:
      return FirstRunEntry.full;
    case FirstRunLaunch.auto:
      if (!hasAccount) return FirstRunEntry.full;
      if (cache != null && firstRunImagesOnlyCacheStates.contains(cache)) {
        return FirstRunEntry.imagesOnly;
      }
      return null;
  }
}

// --- 문구 ---------------------------------------------------------------

const firstRunTitle = '첫 실행 준비';
const firstRunInfoText =
    '플래너를 처음 열 때 한 번만 나옵니다. 언제든 건너뛸 수 있고, 설정에서 다시 열 수 있습니다.';
const firstRunUpdateTitle = '게임이 업데이트되어 이미지를 다시 준비합니다';
const firstRunUpdateInfoText =
    '바뀐 그림만 다시 만듭니다. 기다리는 동안 다른 탭은 열리지 않지만 건너뛸 수 있습니다.';
const firstRunSkipNote = '설정에서 다시 열 수 있습니다';

/// ① 설명 둘째 줄(F3e, F3b 발견 2 CF 문구 — 알파-1은 화면 그림을 번들로 두고 인식 캐시만 준비한다).
// 알파-2(F5b) 시안 문구: '학생 · 아이템 그림은 이 PC의 게임 설치본에서 가져옵니다 — 플래너 배포본에는 그림이 들어 있지 않습니다.'
const firstRunArtSourceNote = '스캔이 게임 화면을 알아보는 데 쓸 그림을 이 PC의 게임 설치본에서 준비합니다.';

const firstRunStepLabels = {
  FirstRunStep.game: '게임 설치 찾기',
  FirstRunStep.images: '이미지 준비',
  FirstRunStep.account: '계정 만들기',
};

/// 폴더를 쓸 수 없는 이유 → (칩, 설명 첫 문장). 시안 문구는 `game_dir_not_found`뿐이고 나머지는 같은 말투로 만들었다.
const firstRunGameDirReasonTexts =
    <AssetGameDirReason, ({String chip, String sentence})>{
      AssetGameDirReason.gameDirNotFound: (
        chip: '찾지 못함',
        sentence: '설치 폴더를 찾지 못했습니다.',
      ),
      AssetGameDirReason.notBlueArchive: (
        chip: '게임 폴더 아님',
        sentence: '이 폴더에는 블루 아카이브가 설치되어 있지 않습니다.',
      ),
      AssetGameDirReason.catalogMissing: (
        chip: '게임 파일 없음',
        sentence: '게임 파일 목록이 없습니다.',
      ),
      AssetGameDirReason.catalogInvalid: (
        chip: '게임 파일 확인 실패',
        sentence: '게임 파일 목록을 읽지 못했습니다.',
      ),
      AssetGameDirReason.bundleRevisionMissing: (
        chip: '게임 버전 없음',
        sentence: '게임 버전 정보가 없습니다.',
      ),
      AssetGameDirReason.bundleRevisionInvalid: (
        chip: '게임 버전 확인 실패',
        sentence: '게임 버전 정보를 읽지 못했습니다.',
      ),
      AssetGameDirReason.bundleRevisionMismatch: (
        chip: '게임 버전 다름',
        sentence: '게임 파일의 버전이 서로 다릅니다.',
      ),
      AssetGameDirReason.gameDirUnreadable: (
        chip: '폴더 읽기 실패',
        sentence: '설치 폴더를 읽지 못했습니다.',
      ),
    };

/// 폴더 이유 뒤에 붙는 안내. 폴더를 잘못 고른 이유는 경로 안내(시안), 게임 파일 문제는 업데이트 안내.
String firstRunGameDirGuide(AssetGameDirReason reason) => switch (reason) {
  AssetGameDirReason.gameDirNotFound ||
  AssetGameDirReason.notBlueArchive ||
  AssetGameDirReason.gameDirUnreadable =>
    'Steam → 게임 → 관리 → 로컬 파일 보기로 연 경로를 넣어 주십시오.',
  _ => '게임을 실행해 업데이트를 마친 뒤 다시 지정해 주십시오.',
};

/// ① 못 찾았을 때 설명 첫 줄(이유 문장 + 안내).
String firstRunGameDirLead(AssetGameDirReason reason) =>
    '${firstRunGameDirReasonTexts[reason]!.sentence} ${firstRunGameDirGuide(reason)}';

/// 준비 요청이 거절된 코드 → 문구(시안 없음).
String firstRunPrepareErrorText(
  AssetPrepareErrorCode code,
  AssetGameDirReason? reason,
) => switch (code) {
  AssetPrepareErrorCode.scannerBusy =>
    '스캔 중에는 그림을 준비할 수 없습니다. 스캔을 끝낸 뒤 다시 시도해 주십시오.',
  AssetPrepareErrorCode.busy => '그림 준비가 이미 진행 중입니다.',
  AssetPrepareErrorCode.invalidGameDir =>
    reason == null
        ? '게임 설치 폴더를 쓸 수 없습니다.'
        : firstRunGameDirReasonTexts[reason]!.sentence,
  AssetPrepareErrorCode.unavailable => '이 연결에서는 그림을 준비할 수 없습니다.',
  AssetPrepareErrorCode.jobNotFound => '준비 작업을 찾지 못했습니다. 다시 시도해 주십시오.',
  AssetPrepareErrorCode.ioError => '준비 상태 파일을 읽거나 쓰지 못했습니다.',
  AssetPrepareErrorCode.invalidPayload => '요청을 보내지 못했습니다.',
};

/// 알파-1 단계 줄(D-ALPHA-SPLIT): 화면 그림(학생 초상 · 엘레프) 줄은 없다.
const firstRunStageRows = [
  AssetPrepareStage.icons,
  AssetPrepareStage.sprites,
  AssetPrepareStage.fonts,
];

const firstRunStageNames = {
  AssetPrepareStage.icons: '아이템 아이콘',
  AssetPrepareStage.sprites: '스캔용 그림',
  AssetPrepareStage.fonts: '글꼴',
};

/// 진행 설명(시안 "아이템 아이콘을 만드는 중").
const firstRunStageActivity = {
  AssetPrepareStage.validating: '게임 버전을 확인하는 중',
  AssetPrepareStage.icons: '아이템 아이콘을 만드는 중',
  AssetPrepareStage.sprites: '스캔용 그림을 만드는 중',
  AssetPrepareStage.fonts: '글꼴을 만드는 중',
  AssetPrepareStage.complete: '마무리하는 중',
};

/// 끝난 작업의 사유 → 짧은 문구(시안 "원본 파일을 읽지 못함").
const firstRunReasonTexts = {
  AssetPrepareReasonCode.assetsMissing: '원본 파일을 찾지 못함',
  AssetPrepareReasonCode.cancelled: '취소함',
  AssetPrepareReasonCode.assetCacheInvalid: '준비한 그림을 확인하지 못함',
  AssetPrepareReasonCode.assetExtractFailed: '원본 파일을 읽지 못함',
  AssetPrepareReasonCode.resultNotSaved: '결과를 저장하지 못함',
};

/// 천 단위 쉼표(시안 "1,380").
String firstRunGrouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 모르는 수는 '—'.
String firstRunCount(int? value) =>
    value == null ? '—' : firstRunGrouped(value);

/// 진행 큰 수 뒤 글자: 분모가 있으면 "/ n개 번들", 없으면 "개 번들"(분모 숨김).
String firstRunProgressSuffix(int? total) =>
    total != null && total > 0 ? '/ ${firstRunGrouped(total)}개 번들' : '개 번들';

/// 단계 줄 수: 분모가 있으면 "done / total", 없으면 "done".
String firstRunStageCount(int done, int? total) => total != null && total > 0
    ? '${firstRunGrouped(done)} / ${firstRunGrouped(total)}'
    : firstRunGrouped(done);

/// 끝난 작업 수 한 줄: "만든 n · 재사용 n · 실패 n"(null은 '—').
String firstRunOutcomeCounts({
  required int? created,
  required int? reused,
  required int? failed,
}) =>
    '만든 ${firstRunCount(created)} · 재사용 ${firstRunCount(reused)} · '
    '실패 ${firstRunCount(failed)}';
