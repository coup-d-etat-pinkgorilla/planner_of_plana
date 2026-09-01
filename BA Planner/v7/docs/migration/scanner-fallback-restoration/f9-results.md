# F9 재고 실제 상세·수량 폴백 진행 기록

2026-09-01 사용자 지시로 R19~R21을 구현했다. 사용자 요청으로 게임창을 재확인한 뒤
실제1280 아이템/장비 상세 선택·정상 복귀·취소 복귀를 통과했다.
Python505개와 Flutter399개 전체 회귀 및 analyze도 통과하여 F9를 완료했다.
F0~F8 source snapshot을 보존하며 F10~F12는 착수하지 않았다.

## 구현과 v6 대조

- 이식 전 계약: `backend/tests/fixtures/inventory_detail_f9_v6_parity.json`.
  v6 `inventory.py:_verify_inventory_slot`, 상세 icon/name matcher, `inventory_count_matcher.py`의
  x표식/자리별 숫자/누락 사유와 `scanner_shared.py`의 상세 ROI·엄격 family gate를 대조했다.
  Qt/config/scanner facade나 v6 런타임 import는 추가하지 않았다.
- R19: 기존 `detail_template_fallback`은 동일 grid crop의 재매칭이었다. 기존 진단 의미를 유지하고
  실제 상세에는 `inventory_detail_template`을 쓴다. 빠른 grid ID/수량 성공은 상세 클릭0회다.
  ID/수량 불확정이면 현재 아이템/장비 페이지와 선택을 확인한 뒤 해당 슬롯을1회 선택한다.
  각 선택 확인 단계마다 최대3회 새 캡처로 선택과 모든 슬롯의 같은 위치를 확인한다.
  최초 선택 테두리가 흐린 경우에도 입력 전에 최대3회 관측한다. 테두리 기준은 낮추지 않는다.
  resolve의 최대 새 캡처는15회, 슬롯 클릭은 선택1회+복귀1회다. 사용/강화 버튼 경로는 없다.
- 실제 아이템/장비 UI는 오른쪽 그리드와 왼쪽 상세가 동시에 있는 **상시 패널**이다.
  별도 상세 닫기 버튼이 없으므로 가상의 닫기 입력을 만들지 않고, 원래 선택 슬롯을 복원한다.
  정상이든 실패/취소든 별도 cleanup 토큰으로 같은 페이지·원래 선택을 확인한다.
  페이지가 바뀌거나 선택을 모르면 복귀 클릭을 추측하지 않는다. 미확인 복귀는 세션 실패로 처리하며
  이미 완료한 슬롯 후보는 보존한다. F10의 필터/정렬/스크롤 복구는 여기서 구현하지 않았다.
- 상세 ID는 해당 source의 전체 icon/name bank를 대조한다. 속한 scan profile을 임의로 가정해
  경쟁 아이템을 제외하지 않는다. icon/name 가중치는 .4/.6, score .88/margin .015;
  무기 성장 부품은 .92/.03으로 더 엄격하다. 계산 비용을 줄이기 위해 icon은 최대80×80,
  name은 최대160×64로 비교하며 인식 threshold를 낮추지 않았다.
- R20: `no_x_templates`/`missing_digit_templates`일 때만 장비 숫자 bank를 아이템 glyph로 대체한다.
  낮은 x/숫자 신뢰도는 bank 교체 사유가 아니다. v6와 달리 장비 화면의 **장비 ROI는 유지**하여
  아이템 위치를 잘못 읽지 않는다. x≥.72/숫자≥.66에 추가 margin .025를 요구한다.
  다자리 선행0, 빈 crop/단색/불명은 거부한다. 수량0은 문자열`0`, 미확정은`null`이다.
- R21: weak_x 복귀에는 같은 슬롯의 확정 grid ID/수량과 별도로 확인된 inventory scan profile이
  모두 필요하다. 계정 profile_id를 대신 쓰지 않으며 원래 grid 신뢰도를 유지한다.
  F9 생산 경로는 필터/정렬 검증을 만들지 않으므로 이 flag가 기본 false다. F10 검증 후 연결할 경계다.
  상세 ID가 grid의 확정 ID와 충돌하면 원래 ID를 검토 후보로 남기고 다른 아이템의 수량을 붙이지 않는다.
  상세가 미확정이면 grid의 낮은 신뢰도 결과를 조용히 성공으로 승격하지 않는다.

구현은 `backend/core/inventory_detail_recovery.py`, `scanner_matchers.py`, `scanner_runtime.py`에 있다.
아이콘/이름/수량 template 및 ROI/페이지 표식은 별도 manifest1041개, 전체 인식 자산3046개다.
native 페이지 표식2종/각2개는 아래 최초 캡처에서 고정했다. v6 이름 bank와 UI 언어의 범위를
넘는 지역화나 다른 해상도의 정확도를 여기서 주장하지 않는다.

## 원본 판독과 실게임 진행 상태

F9 시작 시 게임은 기술 노트 필터의 아이템 목록, 첫 슬롯 백귀야행 기초 노트2344개가 선택되어 있었다.
이후 장비 목록으로 이동된 화면도 확보했다. 원본 캡처는 production Windows capture로 읽기만 했으며
최초 두 캡처에서는 선택 입력을 수행하지 않았다. 이후 검증은 슬롯 선택·복귀 입력만 수행했다.
재화 사용/프로필 저장/학습은 수행하지 않았다.

| native1280 원본 | 상세 ID | 수량 | score / margin |
| --- | --- | ---: | --- |
| 아이템 | Item_Icon_SkillBook_Hyakkiyako_0 | 2344 | .9596 / .0347 |
| 장비 | Equipment_Icon_Exp_3 | 116 | .9764 / .1800 |

두 원본의 첫 슬롯 선택 상태도 확인했다. 장비 count bank만 메모리상 제거하는 회귀에서
장비 ROI+아이템 bank가116을 읽었다. 이는 실제 템플릿 파일 손실이나 자연 실패 사례가 아닌 진단이다.
고정 PNG7은 `backend/tests/fixtures/inventory_detail_f9_live/manifest.json`의 개발 calibration이다.
학습이나 holdout 자료가 아니다. source PNG는 `debug/scanner_f9_live/{item,equipment}-initial/frame.png`.

장비 live probe를 이어가려던 시점에 게임이 minimized여서 ready target을 얻지 못했다. 입력0이다.
Computer Use는 상태 캡처에서 minimized를 보고하고, 현재 창을 다시 선택해 복원을 시도해도
`user input was detected in this window; call get_window_state before continuing`을 반환했다.
안전 guard를 다른 입력 수단으로 우회하지 않았다. 사용자에게 게임 창 표시를 요청하고 자동회귀를 계속했다.
이후 사용자가 “게임창을 다시 확인할것”을 지시했다. 최신 창 상태로 재선택한 뒤 게임이 표시되어
검증을 재개했다. 안전 guard 우회는 없었다. 최초 흐린 선택 테두리로 입력0 중단한 사례도 보존하고,
상기 제한 재촬영 보완 후 다음 production recognizer/recovery probe를 수행했다.

| 실제 슬롯 검증 | 결과 | 입력/복귀 |
| --- | --- | --- |
| 장비 슬롯13 | T10 목걸이306, ID·수량 확정 | 선택1+복귀1, 원래0 확인 |
| 장비 슬롯13 판독 직후 취소 주입 | cancelled, 새 cleanup 토큰으로 복귀 | 선택1+복귀1, 원래0 확인 |
| 아이템 슬롯1 | 백귀야행 일반 노트843, ID·수량 확정 | 선택1+복귀1, 원래0 확인 |
| 아이템 슬롯1 판독 직후 취소 주입 | cancelled, 복귀 완료 | 선택1+복귀1, 원래0 확인 |
| 장비 슬롯1 | Exp2 ID 확정, 수량 미확정 | 선택1+복귀1, 원래0 확인 |
| 장비 슬롯4 | 청사진 ID 미확정, 독립 수량1934 | 선택1+복귀1, 원래0 확인 |

trace는 `debug/scanner_f9_live/{equipment-slot13,equipment-cancel,item-slot1,item-cancel,
equipment-slot1-retry,equipment-slot4}/trace.json`이며 감사 파일에 복제한다.
장비 슬롯1의 grid24K/실제 상세24890은 첫 숫자2와7의 margin .0061로 .025 gate에 못 미쳐
`weak_digit_match`로 남겼다. 약한 숫자에 bank를 교체하거나 기준을 낮추지 않았다.
새 청사진은 상세 ID score .6677/margin .0077로 거부했다. ID 불명의 수량을 다른 ID에 붙이지 않는다.
이는 안전한 partial 사례이며 해당 항목까지 완전 인식했다고 주장하지 않는다.
완료 후 최신 게임창에서 최초 아이템 필터/기본 오름차순/첫 슬롯2344 복귀를 시각 확인했다.
골드407,256,746/청휘석23,536은 유지했다. AP 자연 회복 외 소비 입력은 없다.

## 검증과 재현

- 전용19개: 실제 원본7/ID/수량/선택, 누락 bank만 대체, weak_x 허용/거부,
  ID 충돌, 단색 거부, 실패/취소 복귀, 무응답 입력, 페이지 변경 시 복귀 입력 차단,
  흐린 선택 입력 전 재촬영, grid 성공 클릭0, 수량0/미확정, 미확인 복귀 중단,
  후속 슬롯 복귀 실패 시 완료 슬롯 보존을 확인했다.
- 기존 생산 adapter11/11(37.934s). 최초 전체 Python504/504(260.275s)를 거친 뒤 선택 재촬영
  회귀를 추가했다. 최종 Python505/505(281.977s) 통과.
- Flutter analyze 문제 없음(2.5s), Flutter399/399 순차 테스트 통과(3:20).
- 인식 자산3046개 ready, F9 source17/native7 SHA, 이전 F8 snapshot SHA를 확인했다.
  `codealmanac validate`, `codealmanac health`, `git diff --check` 통과.
- 구 `detail_template_fallback`의 진단 tests는 그대로 유지했다. 프로필 자동 반영/학습 없음.

```powershell
py -3.11 backend/tools/sync_inventory_f9_assets.py
py -3.11 backend/tools/export_inventory_f9_fixtures.py
cd backend
py -3.11 -m unittest discover -s tests -v
cd ../frontend
flutter analyze
flutter test --concurrency=1
```

live 도구 `backend/tools/verify_inventory_f9_live.py`는 현재 확인한 `--target`과 `--output`을 받는다.
기본은 현재 상세 read-only이며, `--slot`이 있을 때만 해당 보이는 슬롯을 선택 후 원래 선택을 복원한다.
`--cancel-after-read`는 취소 cleanup 진단이다. 현재 UI가 불명/최소화면 입력하지 않는다.

한계: 빠른 grid 성공0입력은 adapter 자동회귀로 검증했고, 이번 실게임 probe는 production 상세
recognizer/recovery만 실행했다. 전체 여러 페이지 adapter 스캔·필터/정렬/스크롤은 F10 범위다.
R21 production의 scan-profile 검증 flag는 F10 연결 전까지 false로 안전 차단한다.
native2560/다른 DPI·언어·모든 재고 profile·아이템5자리 이상·약한24890/새 청사진 인식 coverage는
F12 추가 검증이다. 실제 화면7은 calibration이며 독립 holdout 정확도로 해석하지 않는다.
F10은 시작하지 않는다.

증거: `f9-source-manifest.json`, `f9-audit.json`, `f9-python-tests.txt`,
`f9-flutter-analyze.txt`, `f9-flutter-tests.txt`, `f9-diff-check.txt`.
