import 'package:flutter/painting.dart';

/// 첫 실행 ①~③ 모달 좌표(F3b, 시안 `FirstRun-1-Game` · `FirstRun-2-Images` · `FirstRun-3-Account`, 사본
/// `docs/frontend-redesign/prototype/2026-10-20/`).
///
/// 모달은 Studio 섹션 그리드가 아니라 떠 있는 패널이다(FD-019 예외 — 계정 추가 모달 `account_create_modal.dart`와 같다).
/// 좌표는 모두 **패널 왼쪽 위 기준 시안 px**다. 패널은 폭 1500의 80° 평행사변형(r18, 채움 rgba(29,42,58,.98) + lifted
/// shadow 4겹)이고, 기준 viewport 2560×1392의 가운데(시안 ③: 530,460 · 1500×470)에 놓인다. 창이 패널보다 작으면
/// 비율을 유지한 채 줄어든다(계정 추가 모달과 같은 규칙).
///
/// 시안 artboard는 상태 둘(①A · ①B, ②A · ②B · ②만)을 한 장에 위아래로 늘어놓았다. 앱은 한 번에 패널 하나만 띄운다.
const firstRunPanelWidth = 1500.0;
const firstRunPanelRadius = 18.0;

/// 패널 높이: ① 자동으로 찾음 500 · ① 못 찾음 440 · ② 520 · ②만 200 · ③ 470.
const firstRunGameFoundHeight = 500.0;
const firstRunGameMissingHeight = 440.0;
const firstRunImagesHeight = 520.0;
const firstRunImagesOnlyHeight = 200.0;
const firstRunAccountHeight = 470.0;

/// 단계 표시(1 게임 설치 찾기 · 2 이미지 준비 · 3 계정 만들기): 오른쪽 45, 위 28, 높이 34, 칩 사이 선 22×2.
const firstRunStepperRight = 45.0;
const firstRunStepperTop = 28.0;
const firstRunStepperHeight = 34.0;
const firstRunStepperLinkWidth = 22.0;

/// 제목(분홍 사선 막대 7×24 + 경기천년제목 24 + (i))의 왼쪽 위. 왼쪽 변 깊이 + 30.
const firstRunTitleTop = 30.0;
const firstRunGameFoundTitleLeft = 118.0;
const firstRunGameMissingTitleLeft = 107.0;
const firstRunImagesTitleLeft = 121.0;
const firstRunImagesOnlyTitleLeft = 65.0;
const firstRunAccountTitleLeft = 112.0;

/// 설명 두 줄(굵게 17 + 흐림 13.5, 간격 8)의 왼쪽 위와 폭.
const firstRunGameFoundLead = Rect.fromLTWH(106, 98, 1100, 60);
const firstRunGameMissingLead = Rect.fromLTWH(96, 98, 1180, 60);
const firstRunImagesLead = Rect.fromLTWH(110, 98, 1180, 60);
const firstRunAccountLead = Rect.fromLTWH(101, 98, 1100, 60);

// ① 게임 설치 찾기 — 상태 A(자동으로 찾음, 높이 500).

/// `.ihdr` 찾은 폴더.
const firstRunFoundHeaderOffset = Offset(104, 174);

/// 찾은 폴더 상자(909.9×56, r7, 채움 rgba(10,16,24,.55) + 외곽선 rgba(56,81,107,.9)).
const firstRunFoundPathRect = Rect.fromLTWH(87.7, 196, 909.9, 56);

/// 찾음 칩 + 흐린 설명(간격 8).
const firstRunFoundChipOffset = Offset(1016, 210);

/// `.ihdr` 다른 폴더 지정.
const firstRunOtherHeaderOffset = Offset(86, 274);

/// 다른 폴더 입력(768.8×50).
const firstRunOtherInputRect = Rect.fromLTWH(71.2, 296, 768.8, 50);

/// 폴더 고르기(150×50).
const firstRunOtherPickRect = Rect.fromLTWH(856, 296, 150, 50);

/// 다른 폴더 지정이 거절됐을 때 이유 칩(시안 없음 — 찾음 칩과 같은 x, 입력 줄 가운데).
const firstRunOtherReasonOffset = Offset(1016, 308);

const firstRunGameFoundSkipRect = Rect.fromLTWH(34.9, 418, 168, 54);
const firstRunGameFoundSkipNoteOffset = Offset(219, 436);
const firstRunGameFoundPrevRect = Rect.fromLTWH(1094.8, 418, 120, 54);
const firstRunGameFoundNextRect = Rect.fromLTWH(1226.8, 418, 150, 54);

// ① 게임 설치 찾기 — 상태 B(못 찾았을 때, 높이 440).

/// `.ihdr` 설치 폴더.
const firstRunMissingHeaderOffset = Offset(91, 184);

/// 설치 폴더 입력(869.9×56, 분홍 외곽선 강조).
const firstRunMissingInputRect = Rect.fromLTWH(75.4, 206, 869.9, 56);
const firstRunMissingPickRect = Rect.fromLTWH(961.3, 209, 150, 50);

/// 찾지 못함 칩.
const firstRunMissingChipOffset = Offset(1127, 222);

const firstRunGameMissingSkipRect = Rect.fromLTWH(34.9, 358, 168, 54);
const firstRunGameMissingSkipNoteOffset = Offset(219, 376);
const firstRunGameMissingPrevRect = Rect.fromLTWH(1105.4, 358, 120, 54);
const firstRunGameMissingNextRect = Rect.fromLTWH(1237.4, 358, 150, 54);
const firstRunGameMissingHintRight = 411.0;
const firstRunGameMissingHintTop = 375.0;

// ② 이미지 준비(높이 520).

/// 진행 블록(폭 1136): 왼쪽 열 520(큰 수 · 막대 12 · 설명, 간격 12) + 간격 56 + 오른쪽 열 560(단계 줄 34, 간격 6).
const firstRunProgressOffset = Offset(176, 196);
const firstRunProgressLeftWidth = 520.0;
const firstRunProgressGap = 56.0;
const firstRunProgressRightWidth = 560.0;
const firstRunProgressBarHeight = 12.0;
const firstRunStageRowHeight = 34.0;
const firstRunStageRowGap = 6.0;

const firstRunImagesSkipRect = Rect.fromLTWH(34.9, 438, 168, 54);
const firstRunImagesSkipNoteOffset = Offset(219, 456);

/// 다시 시도(일부 실패) · 취소(준비 중, 사용자 결정 2026-10-21) 자리.
const firstRunImagesRetryRect = Rect.fromLTWH(921.2, 438, 150, 54);
const firstRunImagesPrevRect = Rect.fromLTWH(1091.2, 438, 120, 54);
const firstRunImagesNextRect = Rect.fromLTWH(1223.2, 438, 150, 54);
const firstRunImagesHintTop = 455.0;

/// 준비 중에는 그 자리에 "취소"가 있어 안내를 취소 단추 왼쪽(간격 12)으로 옮긴다(시안 상태 A에는 취소가 없다).
const firstRunImagesHintBesideCancelRight = 1500 - 921.2 + 12;

// ②만(게임 업데이트 뒤 앱 시작 때, 높이 200): 한 줄(간격 28) = 큰 수 28 + 막대 520×10 + 설명 + 빈칸 + 건너뛰기(tonal 46).
const firstRunImagesOnlyRowRect = Rect.fromLTWH(57, 98, 1200, 46);
const firstRunImagesOnlyGap = 28.0;
const firstRunImagesOnlyBarSize = Size(520, 10);

// ③ 계정 만들기(높이 470).

const firstRunAccountHeaderOffset = Offset(98, 184);

/// 계정 이름 입력(769.9×56, 분홍 외곽선).
const firstRunAccountInputRect = Rect.fromLTWH(80, 210, 769.9, 56);

/// 입력 아래 흐린 설명.
const firstRunAccountNoteOffset = Offset(82, 276);

/// 만들기 실패 문구(시안 없음 — 설명 아래).
const firstRunAccountErrorOffset = Offset(82, 302);

const firstRunAccountSkipRect = Rect.fromLTWH(40.2, 358, 168, 54);
const firstRunAccountSkipNoteOffset = Offset(224, 376);
const firstRunAccountPrevRect = Rect.fromLTWH(1019.4, 358, 120, 54);
const firstRunAccountStartRect = Rect.fromLTWH(1151.4, 358, 236, 54);
const firstRunAccountHintRight = 113.0;
const firstRunAccountHintTop = 422.0;
