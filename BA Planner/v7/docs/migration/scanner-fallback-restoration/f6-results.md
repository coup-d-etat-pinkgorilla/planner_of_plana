# F6 스킬 상세·전체 보기 검증

2026-08-31. F6 구현·자동회귀·실게임 검증 완료. 전체 통과 후 사용자 요청에 따라 F7을 시작한다.

- v6 스킬/체크박스 흐름과 해금2/3성을 parity로 먼저 고정했다. v6 runtime/Qt 의존성은 없다.
- 기본→F5 성급→F6 잠금/스킬 보완 순서다. 확정 성급에서 잠긴 패시브/서브만 skipped다.
  성급 불명은 잠금으로 추정하지 않는다. 잠금과 확정 숫자가 모순되면 값을 보존해 sticky conflict로 검토하고 계산에서도 배제한다.
- 미확정 스킬만 한 번의 상세 캡처로 보완한다. 기본 성공이면 상세 클릭0회이며 다른 확정 필드를 덮어쓰지 않는다.
- 패널 제목 확인 후 체크박스 on/off/unknown을 구분한다. off만 한 번 클릭하고 재캡처에서 on을 확인한다.
  unknown/무반응은 추가 클릭이나 숫자 판독 없이 F2 동일 학생 복귀 후 partial, 복귀 불명은 안전 중단한다.
- legacy ‘전체 보기’ ROI의 현재 게임 라벨은 ‘일괄 성장 ON’이다. 이는 네 스킬을 동시에 표시하는 모드이며,
  성장 실행·최대 투입·선택권 자동 사용 체크박스는 조작하지 않았다. QA에서는 표시 모드를 off로 준비한 뒤 runtime이 on으로 복구함을 확인했다.
- 고정 자산40개(숫자35, 잠금2, 체크2, ROI1), 총1979개. bank는 최초 실제 판독에만 준비한다.
  첫 자동 검사에서1280 일반5의 margin 부족3건과 테스트 fake 누락1건을 발견했다.
  원본/1280/2560 ROI 크기로 고정 템플릿을 준비하도록 수정했고 임계값을 낮추지 않았다.
  실패 로그 `f6-focused-first-failed.txt` 보존. 최종 전용22 tests 통과.
- 실제1280: 미카5/10/10/10, 미유1/1/1/1; on 유지 클릭0, off→on 클릭1, 같은 학생 복귀와 취소 후 복귀 통과.
  기본 스킬만 미확정으로 주입한 미카 단일 스캔도 상세 복구 성공. 주입은 자연 발생 오류로 주장하지 않는다.
- `debug/scanner_f6_live/`: `mika-panel`, `mika-off-on`, `mika-fallback`, `mika-cancel-final`, `miyu-panel`.
  취소 probe 한 번을 선행 스캔 종료 전에 시작하여 panel_wrong_start로 차단했다(`mika-cancel`).
  새 입력은 발생하지 않았고 선행 스캔 종료 후 독립 재실행은 통과했다. 도구 실행 겹침 이력으로 보존한다.
- native PNG5개와 SHA를 `student_skill_f6_live/manifest.json`에 고정했다. 개발 회귀이며 holdout/자동학습 자료가 아니다.
- 실제1280 낮은값·MAX는 확인했다. 실제 중간 레벨/잠긴1·2성 및2560/DPI/장시간 검증은 F12 coverage로 남긴다.
- F0~F5 historical source snapshots 유지, F6 snapshot 별도. 성장/재화/장비/프로필 변경이나 학습 추가 없음.
- 최종 Python427/427(193.933s), Flutter399/399(순차3:23), analyze 이상0(55.8s).
  자산1979 ready/누락0/손상0, source snapshot20개 SHA 일치, codealmanac validate/health 및 diff 검사 통과.
