# F10 재고 필터·정렬·스크롤 복구 결과

2026-09-01 사용자 지시로 R22~R23을 구현하고 native1280 게임창에서 아이템 전체 tail과
장비 여러 페이지 이동·실패 안전 복구를 확인했다. 최종 Python521개, Flutter399개와 analyze를
통과하여 F10을 완료했다. F0~F9 snapshot은 보존했고 F11~F12는 시작하지 않았다.

## 구현과 v6 대조

- 이식 전 계약은 `backend/tests/fixtures/inventory_navigation_f10_v6_parity.json`에 먼저 고정했다.
  v6 `inventory.py`의 필터 패널 최대2회 열기, item filter/reset/profile/sort 순서,
  정렬 최대3회 확인·2회 보정, 최대60페이지, 행 겹침·꼬리 페이지·부분 실패의 zero-fill 금지를 대조했다.
  Qt/config facade나 v6 runtime import는 추가하지 않았다.
- `backend/core/inventory_navigation.py`가 item/equipment 페이지를 먼저 구분한다. 계정 `profile_id`는
  inventory scan profile로 쓰지 않는다. item은 명시 profile이 없으면 입력 전에 중단하고,
  equipment는 `equipment` profile만 허용한다.
- 필터 패널은 클릭 뒤 확인 가능한 제목/정렬 reference를 최대3회 관측한다. item은 필터 탭,
  reset, profile 필터, 정렬 탭을 명시적으로 누른다. 선물은 v6처럼 ooparts의 x와 note의 y를
  조합한 좌표다. 학생 엘레프는 이름 오름차순, 그 외 item/equipment는 기본 오름차순을 확인한다.
- 누락돼 있던 선물75종의 v6 자연 정렬 순서와 이름을
  `backend/tools/sync_inventory_f10_present_catalog.py`로 생성해 정적 catalog에 연결했다.
  자동 스캔 중 v6 파일을 읽지 않는다. catalog revision은
  `171caccc05d444f1ef0b1116263adce5d55f1433bef65d3358238d0fe1cf6441`이다.
- 이동은 선택된 전경 HWND의 재고 grid 안에서 짧은 SendInput drag를 사용한다. mouse down 뒤
  4단계 상대 이동을 보내며 실패·취소에도 `finally` mouse up을 보낸다. wheel은 drag port가 없는
  기존 fixture의 대체 경계로만 남는다.
- 각 슬롯의 선택 테두리와 수량 baseline을 제외한 내부를 24-bin RGB histogram으로 만들고,
  이전 아래 행과 다음 위 행을 비교한다. item margin .03, 5행 equipment margin .025를 적용한다.
  장비의 반복 청사진 패턴 때문에 score가 높아도 후보 margin이 작으면 중단한다.
- 보통 이동은 확인된 겹침 행을 제외한 새 슬롯만 스캔한다. item tail은 score .88~.94의
  잔여 이동을 별도 증거로 인정해 그 페이지 전체를 정확히 한 번 스캔한다. 기본·복구 입력 모두
  무이동일 때만 끝으로 확정한다. near-zero/애매한 overlap, 입력 실패, 취소는 끝이 아니다.
- 생산 `InventoryMatcherAdapter`는 필터·정렬·profile 순서·끝·미확정이 모두 검증된 경우만
  catalog의 누락 ID를 문자열 `0`으로 채운다. 중단/취소/부분 coverage에서는 완료 슬롯만 보존하고
  zero-fill하지 않는다. F9 weak_x 복귀에도 이 독립 scan profile 증거만 전달한다.

R22/R23 asset은 별도 manifest5개이며 전체 인식 자산은3051개다. native frame8개는
`backend/tests/fixtures/inventory_navigation_f10_live/manifest.json`의 개발 calibration으로 고정했다.
학습 또는 독립 holdout 자료가 아니다.

## native1280 실게임 검증

기술 노트에서는 정렬 reference score .9201로 준비를 확인했다. 짧은 drag 네 번이 각각 한 행을
이동했고 3행 overlap score는 .9804/.9940/.9905/.9928이었다. 마지막 잔여 tail은
score .9072, margin .0375로 전체 페이지 1회를 허용했다. 당시 진단 도구는 tail 뒤 끝 확인을 한 번
더 수행해 기본·복구 drag 모두 무이동인 것도 확인했다. 도구는 이후 tail에서 즉시 멈추도록 수정했다.

장비에서는 정렬 reference score .8762를 확인했다. 두 번의 한 행 이동으로 세 화면을 관측했고
4행 overlap은 .9838/.9887, margin .0662/.0262였다. 세 번째 기본 이동이 불규칙했고 복구 이동도
큰 폭으로 움직여 score .876, margin .002로 거부했다. 기준을 낮추지 않았으며 같은 equipment
filter를 다시 적용해 첫 페이지로 복구했다. 별도 고정 negative frame에서도 두 행 이동이
score .9837이지만 margin .0019여서 거부되는 것을 회귀한다.

초기 PostMessage wheel 무이동, SendInput wheel의 과대 이동, 긴 drag의 과대 이동과 capture timeout
등 실패 trace도 `debug/scanner_f10_live/`에 보존했다. 최종 positive/negative 감사 대상은
`item-tech-notes-terminal-final`과 `equipment-three-pages-retry`다. 클릭은 필터/정렬/확인과 메뉴 이동,
drag는 목록 이동에만 사용했다. 사용·강화·구매·프로필 저장·학습·repository commit은 없었다.

마지막 게임창은 아이템/기술 노트/기본 오름차순/첫 페이지로 복구했다. 첫 슬롯은 백귀야행 기초
기술 노트2347, 골드409,089,809, 청휘석24,394로 시각 확인했다. AP 자연 회복 외 소비 입력은 없다.

## 자동 검증

- F10 전용13/13: filter/sort retry·소진, 계정/profile 분리, 선물75종 순서, 행 overlap,
  no-motion terminal, ambiguous failure, profile 단조성, native positive/tail/negative frame SHA를 확인했다.
- F9/F10 adapter21/21: 검증된 끝만 zero-fill하고 scroll 실패는 완료 entry를 보존한다.
- production adapter12/12: 기존 matcher와 Windows 경계를 유지하며 drag move 실패 후 mouse-up을 확인했다.
- 최종 Python521/521(273.469s) 통과. 그 전 전체 실행은 기존 Studio font 복사에서 Windows
  `Invalid argument` 1건이 발생했으나 단독 즉시 통과했고, 최종 전체 재실행도 통과했다.
- Flutter analyze 문제 없음(2.2s), Flutter399/399 순차 테스트 통과(2:50).
- 인식 자산3051개 ready. `codealmanac validate`, `codealmanac health`, `git diff --check`는 아래
  최종 검사에서 확인한다.

```powershell
py -3.11 backend/tools/sync_inventory_f10_assets.py
py -3.11 backend/tools/sync_inventory_f10_present_catalog.py
py -3.11 backend/tools/export_inventory_f10_fixtures.py
cd backend
py -3.11 -m unittest discover -s tests -v
cd ../frontend
flutter analyze
flutter test --concurrency=1
```

한계: 이번 실게임은 production navigation controller의 필터·정렬·스크롤·복구 경계를 실행했다.
여러 페이지 전체 `InventoryMatcherAdapter` ID/수량 세션과 실제 repository/UI process handoff는
F12 통합 coverage로 남긴다. native1280 한국어 UI만 확인했으며 2560, 다른 DPI/언어, 모든 profile의
실게임 tail은 주장하지 않는다. 장비의 불규칙 세 번째 이동은 안전 중단 증거이며 완전 장비 scan
성공으로 해석하지 않는다. F11은 아직 시작하지 않는다.

증거: `f10-source-manifest.json`, `f10-audit.json`, `debug/f10-python-final-green.txt`,
`debug/f10-flutter-analyze-final.txt`, `debug/f10-flutter-tests-final.txt`.
