# v6 repository characterization

## 확인 범위와 결론

P3는 `v6/core/repository.py`, `merge.py`, `scanner_shared.py`, `inventory_profiles.py`, `db.py`, `db_writer.py`와 직접 호출부를 조사했다. v6 repository는 저장소 경계만 담당하지 않고 config/storage path, SQLite, JSON, metadata, inventory profile, scanner DTO와 merge 함수를 직접 import한다. `ScanRepository`의 주요 직접 사용자는 `v6/main.py`, `reset_inventory_data.py`, `gui/viewer_components/home.py`이며 scanner DTO는 serializer, autosave, DB writer와 scanner/UI review 흐름에도 전달된다. repository 자체 및 inventory merge를 포괄하는 직접 회귀 테스트는 확인되지 않았고, 무기 보정 merge 일부와 profile 정렬 테스트만 존재한다.

## 책임과 결합

- `ScanResult`가 `StudentEntry`/`ItemEntry`를 담아 UI의 save 경로에서 repository로 들어간다. candidate 검토와 확정 current 상태의 타입 경계는 없다.
- repository가 raw scan JSON, current student/inventory, history, backup, fast roster, SQLite current/history를 함께 관리한다.
- student current 조회는 JSON이다. inventory current는 SQLite의 non-empty rows가 우선이며 DB가 비었거나 예외이면 JSON으로 fallback하고, non-empty JSON은 DB에 다시 동기화한다.
- JSON 누락은 기본값, JSON 읽기/parse 오류는 출력 후 기본값이다. inventory DB 오류는 fallback을 위해 삼킨다. 이 오류 은폐는 P4에서 구조화된 source/error 결과로 개선할 대상이다.
- JSON 쓰기는 temporary file과 `os.replace`를 사용한다. 실제 atomic persistence는 P4 범위다.

## student parity

`None`인 신규 값은 기존값을 보존한다. level/star/weapon/equipment level은 max이며 field evidence status가 `ok`인 authoritative weapon fields는 감소도 허용한다. equipment tier `unknown`은 무시한다. additional stat은 integer 0..25만 허용하고 범위 밖이면 기존값을 보존한다. `no_weapon_system`과 `weapon_equipped` 충돌은 기존값을 보존한다. form combat stats는 form/field별 non-null merge다. replace mode는 candidate 값을 그대로 current record로 사용한다. history diff는 실제 merge 결과의 필드 변화만 남긴다.

## inventory parity

canonical key는 stable item ID 우선, 없으면 name이다. 중복 후보 rank는 non-zero quantity, item ID 보유, quantity 문자열 길이 순이다. 신규 quantity가 `None` 또는 빈 문자열이면 기존값을 보존하지만 문자열 `"0"`은 유효하다. 부분 scan은 누락 항목을 보존한다. 명시 profile 교체는 요청 profile과 실제 scanned profile의 교집합에만 적용해 오탐/미스캔 profile의 빈 결과가 삭제를 일으키지 않게 한다. profile 결과는 canonical order와 zero-fill을 적용한다. diff는 추가/수량 변경만 기록하며 삭제나 planning shortage를 만들지 않는다.

## P3 경계와 위험

P3 DTO는 Qt/Pillow/capture/matcher/callback/DB/path를 포함하지 않고 candidate와 confirmed current를 분리한다. 정적 metadata는 기존 `student_meta` 경계를, goal은 기존 `StudentGoal`을 재사용한다. 특히 `display_name`의 owner는 `StudentMeta`이며 v7 `ConfirmedStudent`나 student repository commit에 저장하지 않는다. UI가 current와 이름을 함께 표시하더라도 이는 view 조합이며 저장 bucket을 합치는 것이 아니다. v6 repository/merge의 `display_name`은 legacy parity 특성화만을 위해 유지한다. cost와 shortage는 current/inventory에 들어갈 수 없다. P3 resolver는 이미 읽힌 snapshots만 받아 I/O 없이 source와 SQLite error를 반환한다. v6의 DB fallback 후 resync, 실제 profile catalog 전체, 영속 atomicity는 P4 책임이다. v6 repository의 모든 GUI callback 동작에 대한 자동 검증은 `NOT_VERIFIED`다.

## 다섯 데이터 버킷 field mapping

| 버킷 | 소유 type/module | 대표 field 또는 field group | 원본/파생 | P3/P4 저장 여부 | 금지된 유입 경계 |
|---|---|---|---|---|---|
| 확정 현재 학생/인벤토리 | `ConfirmedStudent`, `InventoryEntry`/`InventorySnapshot` (`repository_dto`) | `level`, `weapon_*`, `quantity`, `profile_id`; `display_name` 제외 | scan 검토로 확정된 원본 상태 | P3 계약만, P4 저장 | metadata, goal, total cost, shortage를 values/entry/commit에 넣지 않음 |
| 정적 메타데이터 | `StudentMeta` (`student_meta_types`) | `display_name`(owner), `school`, `attack_type`, material tables | packaged 정적 원본 | 기존 metadata API만, repository current에 복제하지 않음 | current/candidate/commit values |
| 사용자 목표 | `StudentGoal` (`planning`) | `target_*`, `favorite`, `notes` | 사용자 원본 | P3 기존 type 연결, P4 goal 저장 | current/inventory/candidate confirmed payload |
| 보유량 차감 전 총 필요량 | `PlanCostSummary` (`planning_calc`) | `credits`, `skill_books`, `equipment_materials` | current+goal에서 계산한 파생값 | 저장하지 않고 재계산 | current/inventory/goal/commit |
| 인벤토리 기반 부족량 | 아직 저장 DTO 없음 | `shortage(s)` 의미군 | inventory와 총 필요량에서 향후 계산할 파생값 | P3 저장 금지, 후속 단계에서도 재계산 우선 | 모든 P3 DTO와 repository commit |

테스트는 `dataclasses.fields(StudentGoal/PlanCostSummary/InventoryEntry)`, `StudentMeta.__annotations__`, 기존 student field 상수와 금지 field 상수를 사용해 이 소유권을 기계적으로 확인한다.

## legacy inventory key 제한

legacy map의 외부 key가 display name이어도 entry 내부에 `item_id`가 있으면 item ID가 canonical key다. 반대로 entry에 ID가 없으면 이름만 같은 ID entry로 추측 병합하지 않고 name-only 항목을 보존한다. display name만으로 서로 다른 item을 손실 병합할 수 있기 때문이다. name-only record를 catalog 근거로 ID에 연결하는 migration은 P4에서 명시적으로 구현해야 한다.
