# 학생 스캔 상태 메시지 초안

이 문서는 학생 스캔 중 표시할 상태 메시지를 프라나가 학생부 정리를 보조하는 상황의 대사로 정리한 초안이다.
아직 런타임에 연결하지 않고, 문구와 표시 구조를 먼저 검토한 뒤 실제 스캔 탭 좌측 패널에 반영한다.

## 컨셉

- 프라나는 학생부 정리 업무를 진행 중인 AI 비서처럼 말한다.
- 사용자가 보는 문장은 기계 로그가 아니라 업무 보고 대사에 가깝게 둔다.
- 판정 근거, 점수, ROI, 템플릿 이름 같은 기술 정보는 상세/디버그 영역으로 숨긴다.
- 말투는 짧고 딱딱하게 유지한다.
- 오류는 `오류.`, 불확실한 상황은 `확인 필요.`, 조건상 생략은 `판단 완료.` 같은 접두를 쓸 수 있다.

## 표시 위치 목표

현재 스캔 탭의 좌측 영역에 `프라나 상태 패널`을 둔다.

- 상단: 프라나 이름 또는 작은 상태 헤더
- 중앙: 현재 대사 1~2줄
- 하단: 진행률, 현재 학생, 현재 업무 단계
- 필요 시 펼침: 최근 대사 목록과 상세 로그

작은 기존 오버레이에는 가장 최근 `primary` 대사만 보여주고, 스캔 탭 좌측 패널에는 `primary/result/warning/error`를 누적해서 보여주는 방향이 좋다.

## 표시 레벨

| 레벨 | 사용자 표시 | 용도 |
| --- | --- | --- |
| `primary` | 항상 표시 | 현재 프라나가 수행 중인 업무 |
| `result` | 표시 | 판정 완료 보고 |
| `skip` | 표시 또는 접기 | 조건상 생략한 이유 |
| `warning` | 강조 표시 | 불확실, 재시도, 복구 |
| `error` | 강조 표시 | 중단 또는 실패 |
| `detail` | 기본 접기 | 단계 진행 설명 |
| `debug` | 개발 모드 | 점수, 템플릿, 영역 정보 |

## 이벤트 구조 초안

```python
ScanStatusEvent(
    phase="equipment",
    step="favorite_slot_flag",
    level="warning",
    persona="plana",
    message="확인 필요. 애장품 기록이 불명확합니다. 장비 성장 서류를 직접 확인하겠습니다.",
    technical="equip4 yellow dot may mean T1 upgrade or empty slot",
    student_id="koharu",
    student_name="코하루",
    current=12,
    total=180,
    fields={
        "slot": 4,
        "growth_button_active": True,
        "source": "equipment_menu",
    },
)
```

`message`는 사용자가 보는 프라나 대사다. `technical`과 `fields`는 상세 창이나 로그 저장에만 쓴다.

## 세션 시작/준비

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `session.start` | primary | `학생부를 가져오는 중입니다. 잠시만 기다려 주십시오, 선생님.` |
| `session.target_window.check` | detail | `대상 업무 창을 확인합니다.` |
| `session.target_window.ok` | result | `확인했습니다. Blue Archive 창과 연결되었습니다.` |
| `session.target_window.missing` | error | `오류. 업무 창을 찾을 수 없습니다. 학생부 정리를 시작할 수 없습니다.` |
| `session.profile.load` | detail | `서류 양식을 확인합니다. 화면 영역 정보를 대조하겠습니다.` |
| `session.saved_data.load` | detail | `기존 학생부 기록을 조회합니다.` |
| `session.saved_data.loaded` | result | `기존 기록 확인 완료. 생략 가능한 학생은 {count}명입니다.` |
| `session.student_menu.enter` | primary | `학생 명부로 이동합니다.` |
| `session.student_menu.enter_failed` | error | `오류. 학생 명부를 열지 못했습니다.` |
| `session.first_student.enter` | primary | `첫 번째 학생의 기록 카드를 확인합니다.` |
| `session.first_student.enter_failed` | error | `오류. 첫 번째 학생 기록 카드에 접근하지 못했습니다.` |

## 학생 루프

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `student.identify.start` | primary | `{index}번째 학생의 신원을 확인합니다.` |
| `student.identify.retry` | warning | `오류. 학생의 사진이 잘 판별되지 않는 것 같습니다. 다시 진행합니다.` |
| `student.identify.success` | result | `확인했습니다. {student_name} 학생입니다.` |
| `student.identify.failed` | error | `오류. 학생의 신원을 확정할 수 없습니다. 연속 정리를 중단합니다.` |
| `student.scan.start` | primary | `{student_name} 학생의 학생부를 정리합니다.` |
| `student.scan.saved_max_skip` | skip | `판단 완료. {student_name} 학생은 기존 기록상 정리가 완료되어 있습니다.` |
| `student.scan.commit` | result | `확인했습니다. {student_name} 학생의 기록을 반영했습니다.` |
| `student.scan.partial_commit` | warning | `확인 필요. 일부 항목이 불명확하지만, 가능한 기록을 먼저 반영했습니다.` |
| `student.scan.failed` | error | `오류. 필수 기록이 부족합니다. 이 학생의 기록은 반영하지 않겠습니다.` |
| `student.loop.duplicate` | warning | `확인 필요. 같은 학생 기록이 다시 보입니다. 다음 서류로 넘기겠습니다.` |
| `student.loop.seen_before` | primary | `이미 정리한 학생 기록입니다. 명부의 끝으로 판단합니다.` |
| `student.loop.complete` | result | `학생부 정리를 완료했습니다. 총 {total}명입니다.` |

## 화면 이동/입력

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `navigation.basic_tab.restore` | detail | `기본 정보 서류로 돌아갑니다.` |
| `navigation.basic_tab.restore_failed` | warning | `확인 필요. 기본 정보 서류 복귀가 늦어지고 있습니다.` |
| `navigation.next.arrow` | detail | `다음 학생 기록으로 넘깁니다.` |
| `navigation.prev.arrow` | detail | `이전 학생 기록으로 되돌립니다.` |
| `navigation.next.changed` | result | `확인했습니다. 다음 학생 기록입니다.` |
| `navigation.next.no_change` | warning | `확인 필요. 서류가 넘어가지 않았습니다. 다른 방법으로 넘기겠습니다.` |
| `navigation.next.button_fallback` | detail | `화면의 이동 버튼으로 다음 기록을 요청합니다.` |
| `navigation.wait_after_switch` | detail | `창 전환을 확인 중입니다. 안정화까지 대기합니다.` |
| `navigation.panel.close` | detail | `{panel_name} 서류를 닫습니다.` |
| `navigation.panel.close_retry` | warning | `확인 필요. 닫힘 처리가 늦습니다. 다시 확인하겠습니다.` |
| `navigation.esc_fallback` | warning | `복구 절차를 진행합니다. 열린 서류를 닫겠습니다.` |

## 레벨

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `level.start` | primary | `{student_name} 학생의 레벨 기록을 확인합니다.` |
| `level.saved_max_skip` | skip | `판단 완료. 기존 기록에서 최고 레벨을 확인했습니다.` |
| `level.tab.open` | detail | `레벨 관련 서류를 펼칩니다.` |
| `level.tab.failed` | warning | `오류. 레벨 서류가 제대로 열리지 않았습니다.` |
| `level.read.retry` | warning | `확인 필요. 숫자가 흐릿합니다. 다시 확인하겠습니다.` |
| `level.read.ok` | result | `레벨 기록 확인. Lv.{level}입니다.` |
| `level.read.failed` | warning | `확인 필요. 레벨 숫자를 확정하지 못했습니다.` |

## 전용무기 상태

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `weapon_state.start` | primary | `{student_name} 학생의 전용무기 항목을 확인합니다.` |
| `weapon_state.saved_max_skip` | skip | `판단 완료. 기존 기록에서 전용무기 정리 완료 상태를 확인했습니다.` |
| `weapon_state.no_system` | result | `확인했습니다. 전용무기 항목은 아직 열려 있지 않습니다.` |
| `weapon_state.unlocked_not_equipped` | result | `확인했습니다. 전용무기는 해금되어 있으나 장착 기록이 없습니다.` |
| `weapon_state.equipped` | result | `확인했습니다. 전용무기 장착 기록이 있습니다.` |
| `weapon_state.uncertain` | warning | `확인 필요. 전용무기 항목의 표시가 애매합니다. 추가 확인이 필요합니다.` |
| `weapon_state.region_missing` | warning | `확인 필요. 전용무기 확인란을 찾지 못했습니다. 미해금으로 임시 처리합니다.` |

## 성급

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `star.start` | primary | `{student_name} 학생의 성급 기록을 확인합니다.` |
| `star.infer_from_weapon` | skip | `판단 완료. 전용무기 기록이 있으므로 5성으로 처리합니다.` |
| `star.weapon_uncertain_direct_scan` | detail | `전용무기 기록만으로는 부족합니다. 성급 서류를 직접 확인합니다.` |
| `star.menu.open` | detail | `성급 서류를 펼칩니다.` |
| `star.menu.failed` | warning | `오류. 성급 서류가 열리지 않았습니다.` |
| `star.read.ok` | result | `성급 기록 확인. {star}성입니다.` |
| `star.read.uncertain` | warning | `확인 필요. 별의 개수가 명확하지 않습니다. 기록을 주의 표시합니다.` |

## 스킬

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `skills.start` | primary | `{student_name} 학생의 스킬 기록을 정리합니다.` |
| `skills.saved_max_skip` | skip | `판단 완료. 기존 기록에서 스킬 성장이 완료되어 있습니다.` |
| `skills.menu.open` | detail | `스킬 성장 서류를 펼칩니다.` |
| `skills.menu.failed` | warning | `오류. 스킬 성장 서류를 열지 못했습니다.` |
| `skills.all_view.enable` | detail | `전체 스킬 기록이 보이도록 정렬합니다.` |
| `skills.ex.ok` | result | `EX 스킬 기록 확인. Lv.{level}입니다.` |
| `skills.skill1.ok` | result | `기본 스킬 기록 확인. Lv.{level}입니다.` |
| `skills.skill2.ok` | result | `강화 스킬 기록 확인. Lv.{level}입니다.` |
| `skills.skill3.skip_star_locked` | skip | `판단 완료. 서브 스킬은 {star}성 상태에서 아직 해금되지 않습니다.` |
| `skills.skill3.ok` | result | `서브 스킬 기록 확인. Lv.{level}입니다.` |
| `skills.read.failed` | warning | `확인 필요. {skill_name} 기록을 읽기 어렵습니다.` |
| `skills.summary` | result | `스킬 기록 정리 완료. EX {ex}, 기본 {s1}, 강화 {s2}, 서브 {s3}입니다.` |

## 전용무기 상세

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `weapon.start` | primary | `{student_name} 학생의 전용무기 상세 기록을 확인합니다.` |
| `weapon.skip_star_locked` | skip | `판단 완료. {star}성 상태에서는 전용무기 상세 기록이 열리지 않습니다.` |
| `weapon.skip_no_system` | skip | `판단 완료. 전용무기 항목이 없어 상세 확인을 생략합니다.` |
| `weapon.skip_not_equipped` | skip | `판단 완료. 전용무기가 미장착 상태라 상세 수치를 기록하지 않습니다.` |
| `weapon.menu.open` | detail | `전용무기 상세 서류를 펼칩니다.` |
| `weapon.menu.failed` | warning | `오류. 전용무기 상세 서류를 열지 못했습니다.` |
| `weapon.star.ok` | result | `전용무기 성급 기록 확인. {star}성입니다.` |
| `weapon.star.uncertain` | warning | `확인 필요. 전용무기 성급 표시가 명확하지 않습니다.` |
| `weapon.level.retry` | warning | `확인 필요. 전용무기 레벨 숫자가 흐릿합니다. 다시 확인합니다.` |
| `weapon.level.ok` | result | `전용무기 레벨 기록 확인. Lv.{level}입니다.` |
| `weapon.summary` | result | `전용무기 기록 정리 완료. {star}성 Lv.{level}입니다.` |

## 장비 공통

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `equipment.start` | primary | `{student_name} 학생의 장비 기록을 정리합니다.` |
| `equipment.saved_max_skip` | skip | `판단 완료. 기존 기록에서 장비 정리 완료 상태를 확인했습니다.` |
| `equipment.favorite_saved_max_skip` | skip | `판단 완료. 기존 기록에서 애장품 정리 완료 상태를 확인했습니다.` |
| `equipment.button.active` | detail | `장비 성장 서류가 열람 가능한 상태입니다.` |
| `equipment.button.inactive` | detail | `장비 성장 서류가 비활성 상태입니다. 잠금 여부를 추가 확인합니다.` |
| `equipment.basic_dot.slot1_empty` | result | `장비1 기록 확인. 장착 가능한 장비가 있으나 아직 비어 있습니다.` |
| `equipment.basic_dot.favorite_empty` | result | `애장품 기록 확인. 장착 가능한 물품이 있으나 아직 비어 있습니다.` |
| `equipment.menu.open` | detail | `장비 성장 서류를 펼칩니다.` |
| `equipment.menu.failed` | warning | `오류. 장비 성장 서류를 열지 못했습니다.` |
| `equipment.all_view.enable` | detail | `모든 장비 항목이 보이도록 정렬합니다.` |
| `equipment.all_view.failed` | warning | `확인 필요. 장비 항목 정렬이 불안정합니다. 보이는 기록으로 계속 진행합니다.` |
| `equipment.retry.capture` | warning | `확인 필요. 장비 기록이 흐릿합니다. 다시 확인합니다.` |
| `equipment.close` | detail | `장비 성장 서류를 닫습니다.` |

## 장비1

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `equip1.start` | primary | `첫 번째 장비 기록을 확인합니다.` |
| `equip1.empty` | result | `장비1 기록 확인. 미장착 상태입니다.` |
| `equip1.tier.ok` | result | `장비1 티어 기록 확인. {tier}입니다.` |
| `equip1.level.ok` | result | `장비1 레벨 기록 확인. Lv.{level}입니다.` |
| `equip1.tier.uncertain` | warning | `확인 필요. 장비1의 티어 표시가 명확하지 않습니다.` |
| `equip1.level.failed` | warning | `확인 필요. 장비1의 레벨 숫자를 확정하지 못했습니다.` |

## 장비2

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `equip2.skip_level_locked_from_level` | skip | `판단 완료. 장비2는 Lv.{level} 상태에서 아직 해금되지 않습니다.` |
| `equip2.button_off_empty` | result | `장비2 기록 확인. 장비 성장 서류가 비활성 상태이므로 미장착으로 처리합니다.` |
| `equip2.slot_flag.empty` | result | `장비2 기록 확인. 미장착 상태입니다.` |
| `equip2.slot_flag.level_locked` | result | `장비2 기록 확인. Lv.10 제한으로 잠겨 있습니다.` |
| `equip2.tier.ok` | result | `장비2 티어 기록 확인. {tier}입니다.` |
| `equip2.level.ok` | result | `장비2 레벨 기록 확인. Lv.{level}입니다.` |
| `equip2.tier.uncertain` | warning | `확인 필요. 장비2의 티어 표시가 명확하지 않습니다.` |

## 장비3

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `equip3.skip_level_locked_from_level` | skip | `판단 완료. 장비3은 Lv.{level} 상태에서 아직 해금되지 않습니다.` |
| `equip3.button_off_empty` | result | `장비3 기록 확인. 장비 성장 서류가 비활성 상태이므로 미장착으로 처리합니다.` |
| `equip3.slot_flag.empty` | result | `장비3 기록 확인. 미장착 상태입니다.` |
| `equip3.slot_flag.level_locked` | result | `장비3 기록 확인. Lv.20 제한으로 잠겨 있습니다.` |
| `equip3.tier.ok` | result | `장비3 티어 기록 확인. {tier}입니다.` |
| `equip3.level.ok` | result | `장비3 레벨 기록 확인. Lv.{level}입니다.` |
| `equip3.tier.uncertain` | warning | `확인 필요. 장비3의 티어 표시가 명확하지 않습니다.` |

## 애장품

애장품은 기본 화면의 노란 점만으로 판정하지 않는다.
T1 성장 가능 상태와 장착 가능 미장착 상태가 같은 노란 점으로 보일 수 있기 때문이다.
프라나 대사에서는 이 과정을 “애장품 서류를 직접 확인한다”는 식으로 표현한다.

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `favorite.start` | primary | `{student_name} 학생의 애장품 기록을 확인합니다.` |
| `favorite.unsupported` | result | `애장품 기록 확인. 이 학생에게는 해당 항목이 존재하지 않습니다.` |
| `favorite.growth_off_dot_empty` | result | `애장품 기록 확인. 장착 가능한 물품이 있으나 아직 비어 있습니다.` |
| `favorite.growth_on_needs_menu` | detail | `확인 필요. 노란 표시만으로는 애장품 상태를 확정할 수 없습니다. 상세 서류를 확인합니다.` |
| `favorite.slot_flag.empty` | result | `애장품 기록 확인. 미장착 상태입니다.` |
| `favorite.slot_flag.love_locked` | result | `애장품 기록 확인. 인연도 조건으로 잠겨 있습니다.` |
| `favorite.slot_flag.null` | result | `애장품 기록 확인. 존재하지 않는 항목입니다.` |
| `favorite.tier.t1` | result | `애장품 기록 확인. T1 장착 상태입니다.` |
| `favorite.tier.t2` | result | `애장품 기록 확인. T2 장착 상태입니다.` |
| `favorite.tier.uncertain` | warning | `확인 필요. 애장품 등급 표시가 명확하지 않습니다.` |
| `favorite.love_lock.avoid_basic` | debug | `기본 화면의 인연도 잠금 하트는 배경 영향을 받을 수 있어 최종 판정에 사용하지 않습니다.` |

## 능력 개방

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `stats.start` | primary | `{student_name} 학생의 능력 개방 기록을 확인합니다.` |
| `stats.skip_condition` | skip | `판단 완료. Lv.{level}, {star}성 상태에서는 능력 개방 기록을 확인하지 않습니다.` |
| `stats.saved_max_skip` | skip | `판단 완료. 기존 기록에서 능력 개방 정리 완료 상태를 확인했습니다.` |
| `stats.menu.open` | detail | `능력 개방 상세 서류를 펼칩니다.` |
| `stats.menu.failed` | warning | `오류. 능력 개방 상세 서류를 열지 못했습니다.` |
| `stats.hp.ok` | result | `체력 기록 확인. {value}입니다.` |
| `stats.atk.ok` | result | `공격력 기록 확인. {value}입니다.` |
| `stats.heal.ok` | result | `치유력 기록 확인. {value}입니다.` |
| `stats.value.uncertain` | warning | `확인 필요. {stat_name} 수치가 명확하지 않습니다.` |
| `stats.summary` | result | `능력 개방 기록 정리 완료. 체력 {hp}, 공격력 {atk}, 치유력 {heal}입니다.` |

## 중단/복구/오류

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `stop.requested` | warning | `중지 요청 확인. 현재 서류를 정리한 뒤 멈추겠습니다.` |
| `stop.spacebar` | warning | `긴급 중지 신호를 확인했습니다. 작업을 중단합니다.` |
| `capture.failed` | warning | `오류. 현재 화면을 기록하지 못했습니다. 다시 확인합니다.` |
| `capture.target_closed` | error | `오류. 업무 창과의 연결이 끊어졌습니다.` |
| `recover.first_student` | warning | `확인 필요. 첫 학생 기록 접근이 불안정합니다. 복구를 시도합니다.` |
| `recover.panel_unknown` | warning | `확인 필요. 열린 서류의 종류를 확정하지 못했습니다. 기본 서류로 복귀합니다.` |
| `autosave.partial` | warning | `예외 상황 확인. 현재까지 정리한 학생부를 임시 저장합니다.` |
| `scan.exception` | error | `오류. 학생부 정리 중 예외가 발생했습니다. {error}` |

## 최종 요약

| ID | 레벨 | 프라나 대사 |
| --- | --- | --- |
| `summary.student.compact` | result | `{student_name} 학생부 정리 완료. Lv.{level}, {star}성입니다.` |
| `summary.student.uncertain` | warning | `확인 필요. {student_name} 학생의 일부 기록이 불명확합니다: {fields}` |
| `summary.student.failed` | warning | `확인 필요. {student_name} 학생의 미기록 항목이 있습니다: {fields}` |
| `summary.session.done` | result | `학생부 정리를 완료했습니다. 총 {total}명입니다.` |
| `summary.session.done_with_counts` | result | `학생부 정리를 완료했습니다. 정리 {scanned}명, 생략 {skipped}명, 확인 필요 {warnings}건입니다.` |

## 좌측 패널에 우선 보여줄 문구

처음부터 모든 메시지를 표시하면 과하게 느껴질 수 있다. 좌측 패널에는 아래 정도를 우선 연결한다.

- `session.start`
- `session.student_menu.enter`
- `student.identify.start`
- `student.identify.retry`
- `student.identify.success`
- `student.scan.start`
- `level.start`, `level.read.ok`
- `weapon_state.start`, `weapon_state.*`
- `star.start`, `star.read.ok`, `star.infer_from_weapon`
- `skills.start`, `skills.summary`
- `weapon.start`, `weapon.skip_*`, `weapon.summary`
- `equipment.start`, `equipment.button.*`
- `equip2.*`, `equip3.*`, `favorite.*`
- `stats.skip_condition`, `stats.summary`
- `summary.student.compact`
- `summary.session.done_with_counts`

## 프라나 일러스트 표정 세트

프라나 일러스트는 메시지 레벨과 현재 업무 상태에 맞춰 바꾼다.
처음에는 표정 수를 적게 잡고, 이후 대사 밀도가 늘어나면 확장한다.

### 최소 세트

| 표정 ID | 용도 | 어울리는 메시지 |
| --- | --- | --- |
| `neutral` | 기본 대기, 일반 안내 | `접속 확인. 선생님, 기다리고 있었습니다.`, `학생부를 가져오는 중입니다.` |
| `working` | 스캔 진행, 서류 확인 | `학생 명부로 이동합니다.`, `{student_name} 학생의 학생부를 정리합니다.` |
| `confirm` | 판정 완료, 정상 결과 | `확인했습니다. {student_name} 학생입니다.`, `레벨 기록 확인. Lv.{level}입니다.` |
| `thinking` | 추가 확인, 애매한 판정 | `확인 필요. 노란 표시만으로는 애장품 상태를 확정할 수 없습니다.` |
| `warning` | 재시도, 불안정, 주의 | `오류. 학생의 사진이 잘 판별되지 않는 것 같습니다. 다시 진행합니다.` |
| `error` | 실패, 중단, 연결 끊김 | `오류. 학생의 신원을 확정할 수 없습니다.`, `업무 창과의 연결이 끊어졌습니다.` |

이 6개면 현재 상태 메시지 대부분을 자연스럽게 커버할 수 있다.

### 권장 확장 세트

| 표정 ID | 용도 | 설명 |
| --- | --- | --- |
| `idle_soft` | 대기/친밀감 | 스캔 전 좌측 패널 기본. 너무 딱딱하지 않은 무표정 또는 약한 미소. |
| `focused` | 집중 판독 | 학생 식별, 레벨/성급/장비 판독처럼 화면을 자세히 보는 단계. |
| `writing` | 기록 반영 | 학생부 기록 저장, 결과 반영, 요약 작성 단계. |
| `satisfied` | 스캔 성공 | 학생 1명 완료, 전체 스캔 완료. 과한 웃음보다 작게 만족한 느낌. |
| `unsure` | 확인 필요 | 템플릿 점수 낮음, 애장품 노란 점, 별/티어 불확실. |
| `alert` | 경고/재시도 | 캡처 실패, 학생 식별 재시도, 이동 실패 fallback. |
| `error` | 오류/중단 | 치명 오류, 대상 창 없음, 학생 식별 최종 실패. |
| `stop` | 중지 요청 | 사용자가 중지했거나 스페이스바 긴급 중지 감지. |
| `skip_judged` | 조건 판단 완료 | Skill3 미해금, 전용무기 미해금, 장비 잠금 등 조건상 생략. |
| `confused_touch` | 상호작용용 | 나중에 패널 클릭/터치 반응을 넣을 때. “혼란. 이해할 수 없는 행동입니다.” 계열. |

### 메시지 레벨 매핑

| 메시지 레벨 | 기본 표정 | 대체 표정 |
| --- | --- | --- |
| `primary` | `working` | `focused` |
| `result` | `confirm` | `satisfied` |
| `skip` | `skip_judged` | `confirm` |
| `warning` | `warning` | `unsure` |
| `error` | `error` | 없음 |
| `detail` | `working` | `neutral` |
| `debug` | 변경 없음 | 없음 |

### 스캔 단계별 표정

| 단계 | 권장 표정 |
| --- | --- |
| 스캔 대기 | `idle_soft` |
| 학생부 준비/학생 메뉴 이동 | `working` |
| 학생 식별 | `focused` |
| 학생 식별 성공 | `confirm` |
| 학생 식별 재시도 | `alert` |
| 레벨/성급/스킬/장비 판독 | `focused` |
| 애장품 노란 점처럼 애매한 조건 | `unsure` |
| 조건상 스캔 생략 | `skip_judged` |
| 학생 1명 완료 | `writing` 또는 `satisfied` |
| 전체 완료 | `satisfied` |
| 중지 요청 | `stop` |
| 오류 발생 | `error` |

### 파일 구성 제안

처음에는 아래 이름으로 투명 PNG 또는 WebP를 준비하면 된다.

```text
assets/plana/neutral.png
assets/plana/working.png
assets/plana/confirm.png
assets/plana/thinking.png
assets/plana/warning.png
assets/plana/error.png
```

확장 시에는 `idle_soft`, `focused`, `writing`, `satisfied`, `unsure`, `alert`, `stop`, `skip_judged`, `confused_touch`를 추가한다.

좌측 패널 구현에서는 이벤트에 `expression` 필드를 추가하거나, `level`과 `phase`로 자동 선택하면 된다.
초기 구현은 자동 선택이 단순하다.

## 구현 순서 제안

1. 이 문서에서 프라나 대사 톤을 확정한다.
2. 스캔 탭 좌측에 `프라나 상태 패널` 자리만 만든다.
3. 기존 `on_progress_state`는 유지하고, 별도 `on_status_event` 콜백을 추가한다.
4. 스캐너 내부에는 `_status(id, level, message, technical=None, **fields)` 헬퍼를 둔다.
5. 첫 연결은 학생 루프, 레벨, 성급, 장비/애장품 조건 메시지만 한다.
6. 베타 테스트 중에는 상세 로그를 켜고, 기본 UI에서는 프라나 대사만 보여준다.


