# F0 의존성과 결정 기록

2026-08-30 사용자는 D1/D3 제안에 “그렇게 할것”으로 동의했다. 두 정책은 승인 완료다.
F0는 목표 계약을 고정하며 런타임 변경은 후속 단계에서 수행한다.

## 호출과 상태 소유권

v6 `main.py`/`ScannerRuntimeComponent.run_full_scan`은 `Scanner.scan_students`를 통해
`scan_students_v5 → identify_student → _scan_student_fields`를 호출한다. `Scanner`는
`_bind_scanner_component`로 component 함수를 facade globals에 다시 바인딩하고
`scanner_shared`의 DTO·상수·matcher·input을 공유한다. 그 facade/글로벌 구조를 복사하지 않는다.

v7 진입점은 `build_scanner_service → ScannerSessionService._run → StudentMatcherAdapter` 또는
`InventoryMatcherAdapter`다. Windows 입력·캡처, ROI recognizer, 후보 검증과 repository는 별도 경계다.
R별 함수/상태/이벤트의 상세 출처는 source manifest와 restoration matrix를 따른다.
자동 추출 caller는 이름 기반 정적 참조이므로 같은 이름의 다른 method, callback, alias를
동적 실행 증거로 해석하지 않는다. matrix의 수동 호출 경로와 함께 검토한다.

| matrix 의존성 그룹 | v6 의존성 | v7 분리 경계와 후속 주의점 |
|---|---|---|
| capture_input | HWND·rect·capture source size, `_stop_requested`, `_wait`, `_status`, Win32/input globals | `WindowsCaptureInputAdapter`, `CapturePort`/`ClickCapturePort`, `threading.Event`, `ScannerError`; API 성공과 화면 성공 구별 |
| panel | `_active_student_panel`, `self.r`, 제목/활성탭 predicate, adaptive transition history, captured close coordinates | 현재 Equipment/WeaponMenuCaptureAdapter는 클릭+안정 프레임; F2에서 패널 상태와 bounded cleanup 소유 |
| student | `StudentEntry`, `FieldMeta`/`FieldStatus`/`FieldSource`, `ScanCtx`, `ScreenCropSet`, `_asv`, `_field_confirmed`, 폼 stats | `StudentBasicCropSet`/`Observation` → raw candidate → `SessionCandidate`/`ConfirmedStudent`; UI callback 대신 typed evidence/progress/feedback |
| inventory | `ItemEntry`, `InventoryVerification`, `InventoryPageSnapshot`, `InventoryMotionEstimate`, `InventoryGridInput`, profile ordinal/anchors/zero-fill | `InventorySnapshot` entries와 evidence, account `profile_id`와 inventory scan profile 분리; 실제 상세 input/close 경계 신규 필요 |
| calibration | `_basic_level_run_templates`, `_equip_level_run_templates`, detail answer→basic crop, `_asv` callbacks | session-local bank는 별도 lifecycle; `RecognitionAnswerSampleStore`는 사용자 확인 영구 경계 유지 |

v7 callback은 `progress(current,total,message_key,feedback?)`, `EventSink`, `StudentValidator`,
`CandidateReviewHook`이다. 이벤트는 session_id/generation/sequence와 phase/progress/feedback/candidate/terminal을
가지며 terminal은 정확히 한 번이다. `feedback`은 미리 보이는 UI 상태일 뿐 보존된 candidate가 아니다.
이미지 specimen은 backend-only이며 wire/진단 export에 포함하지 않는다.

## 현재 호출 경로에서 확인한 차이

- R02: v6 `go_previous_student_fast`는 helper로 존재하지만 현재 `scan_students_v5`에서 호출되지 않는다.
  실제 전체 순회는 오른쪽이다. v7은 오른쪽 끝에서 왼쪽으로 전환하지만 `press_key`가 right만 허용하여
  예외가 버튼 대체를 막는다. 왼쪽 복구는 이 v7 경로의 안전성까지 포함한다.
- R22: 표에 처음 적었던 `_open_inventory_filter_panel`은 해당 production 경로에서 호출되지 않는다.
  실제 `scan_items/scan_equipment → _prepare_*`는 `_open_item_inventory_filter_panel`과
  `_open_equipment_inventory_filter_panel`을 사용한다. 두 함수 모두 최초 포함 2회 열기를 시도한다.
- R05: 현재 `observations.update(fallback)`은 기본 확정값을 미확정 상세값으로 덮을 수 있다.
  retry 병합도 이전 확정값보다 confidence가 높은 미확정값을 채택할 수 있다. 열기 호출이 try 밖이므로
  부분적으로 열린 뒤 capture 예외가 나면 caller의 finally에 도달하지 않는다. F2의 별도 회귀 대상이다.
- R15: `favorite_growth_active`는 recognizer에 있지만 호출자가 값을 넣지 않는다. 기존 dot bool은
  불명과 부재를 합치므로 새 잠금 추론에 그대로 쓰지 않는다.
- R16: 현재 저신뢰 학생 ID도 장비 family context에 전달된다. 새 복구에서는 ID 불확정 시
  다른 학생의 필드를 확정하지 않는 경계가 필요하다.
- R19/R21: `detail_template_fallback`는 현재 동일 grid crop 재매칭이다. v6 상세 함수의 `if not count`도
  수량0을 실패로 취급할 수 있어 v7로 복사하지 않는다. 실제 상세 닫기는 v6 caller가 소유한다.
- R24: 기존 장비 임시 bank는 recognizer 인스턴스 수명에 묶여 있다. 사용자 숫자 bank 재로드만으로
  session-local calibration 폐기가 보장되지는 않는다. F11에서 lifecycle을 명시적으로 연결한다.

## D1 — 승인 완료

자동 보정은 현재 session 안에서만 사용한다. 계정·실제 해상도·session/generation·학생/폼·필드를
구분하고, 목표 상세 패널에서 독립적으로 확정한 충돌 없는 값만 사용한다. 사용자 정답을 우선한다.
취소·종료·계정/해상도 변경에서 폐기한다. 사용자 명시 수정/확인 전에는 자동 샘플을 영구 저장하거나
재시작 후 재사용하지 않는다. 자동 출력으로 자신을 다시 학습시키지 않는다.

## D2 — legacy 특성화 및 F7 native1280 제한 적용

v6 `_scan_equip_slot`의 일반 tier gate는 0.72다. 그 미만일 때에만 `scan_level=true`,
레벨70, top1=T10, score≥0.66이면 `INFERRED/INFERRED`와 `level70_implies_t10`을 기록한다.
0.66 포함·0.72 미만, 69/null/다른 top1/scan_level=false 경계를 decision fixture에 고정했다.
이 fixture는 실제 이미지 판독 성능을 증명하지 않는다.

현재 v7 bank의 점수는 v6 점수와 직접 등치할 수 없다. F7에서 실제 T10/70과 T1~9,
blank/noise/동률/잘못된 family 음성 fixture를 별도 validation partition으로 측정하기 전까지
승격하지 않는다. 공통 threshold를 내리지 않으며 채택하더라도 제한된 inferred source로 표시한다.

2026-08-31 후속: 독립 native1280 상세8장/24슬롯(T1~T10) 정답 확인, 합성 손상120건에서
복구5/오승격0, blank/noise/wrong-family321건에서 오승격0을 확인했다.
미카 개발 자료와 새 학생 검증 자료를 분리했고 어느 자료도 bank에 추가하지 않았다.
`D2-native1280-v1`은 top1 T10 score[.55,.60), margin≥.15이며 독립 숫자7/0 각각
score≥.80/margin≥.15일 때에만 두 필드를 `equipment_level70_t10` inferred source로 출력한다.
일반 .60 threshold는 유지하고 기본 레벨 보정 학습에서 제외한다.
자연 발생 저점수 양성은 아직 없으며 실제2560 특수 규칙은 비활성이다.
합성 검증을 자연 오류 복구율로 주장하지 않는다. 상세 근거·제약은 `f7-results.md`에 기록했다.

## D3 — 승인 완료

화면 상태를 확인할 수 없으면 안전 중단한다. 화면이 확인되고 일부 필드만 실패한 경우에는
그 필드를 미확정/partial로 남긴다. 이미 끝까지 수집한 후보는 실패·취소 후에도 session 메모리와
snapshot/candidate 조회에 남겨 검토할 수 있게 한다. 작업 중인 후보의 불완전 입력은 수집 완료로
간주하지 않는다. 자동 저장·자동 승인·자동 repository 반영은 하지 않는다.

예정 내부 DTO는 `candidates`, `outcome`, `error`, `screen_state`, `coverage_complete`를 소유한다.
이는 fixture의 목표 모델이며 지금 protocol v1에 추가된 필드가 아니다. F1/F2 구현 시 matcher가
예외만 던져 누적 list를 잃지 않게 내부 결과/실패 전달을 분리하고, session은 후보를 먼저 공개한 뒤
단일 failed/cancelled terminal을 발행한다. terminal 뒤에 candidate 이벤트를 새로 보내지 않는다.
일괄 인연 검증은 실제 수집된 후보 집합만 사용한다.

현재 `_run`은 matcher가 list를 반환한 후에야 candidate를 만들고 취소이면 list를 폐기한다.
따라서 이 보존 동작은 아직 구현되어 있지 않다. completed session만 commit할 수 있는 기존 규칙은
유지한다. 실패·취소 session의 보존 후보는 검토용이며 commit을 허용하도록 이 작업이 승인한 것은 아니다.
session/service 폐기까지의 메모리 보존이며 재시작 복원이나 디스크 진단 자동 저장도 포함하지 않는다.

취소 후에는 정리용 닫기/복귀 외 새 탐색을 하지 않는다. 닫기·기본 복귀도 횟수와 시간 상한을 둔다.
재고의 coverage가 불완전하면 zero-fill하지 않는다. 각 구체 상한은 F1/F2 해당 fixture에서 고정한다.
