---
title: "Metadata Manager Workflow"
summary: "v7 학생·아이템 메타데이터의 출처를 SchaleDB 크롤링에서 공용 클라이언트 자료 저장소(ba-client-data)로 옮기고(SchaleDB 제거), 메타데이터 뷰어·자산 매핑 검증·게임 패치 후 갱신·배포 스냅샷을 배포본에 포함되지 않는 한 개발 도구(metadata-manager)로 묶는 M0~M6 실행 계약입니다."
topics: [workflow, data, tooling, release]
sources:
  - id: devtools-migration
    type: file
    path: docs/migration/developer-tools-migration.md
  - id: devtools-backend
    type: file
    path: backend/tools/developer_tools.py
  - id: devtools-entry
    type: file
    path: frontend/lib/developer_tools_main.dart
  - id: stats-sync
    type: file
    path: backend/tools/sync_student_stats_from_extracted.py
  - id: canonical-export
    type: file
    path: backend/tools/export_canonical_metadata.py
  - id: asset-spec
    type: file
    path: backend/tools/asset_spec/README.md
  - id: asset-connection
    type: file
    path: docs/migration/v6-asset-backend-connection/output.md
  - id: game-assets
    type: file
    path: frontend/lib/ui/kit/game_assets.dart
  - id: data-lock
    type: file
    path: ba-data.lock
---

# Metadata Manager Workflow

## 목적

v6~v7의 학생 메타데이터 편집기는 SchaleDB를 크롤링해 인연 선물 필드를 채웠다. 이제 공용 클라이언트 자료 저장소(`C:\Users\brigh\ba-client-data`, 버전 고정·해시 검증·단일 쓰기)가 있으므로 **출처를 저장소로 바꾸고**, 흩어져 있던 세 가지 일을 한 도구로 모은다. [@devtools-migration]

1. **메타데이터 뷰어/편집기** — v7이 학생마다 실제로 보여 주는 값(canonical 메타데이터, 스탯 카탈로그, 선물 친화도, 폼, KR/JP 서버 상태)과 그 값의 **출처·버전**을 한 화면에서 본다.
2. **자산 매핑 검증** — 플래너 asset 경로 ↔ Addressables 주소 키 ↔ 번들 파일 ↔ 텍스처 이름 매핑이 현재 저장소 버전과 사용자 설치본에서 아직 유효한지 검사한다. [@asset-spec] [@asset-connection]
3. **업데이트·배포 관리자** — 게임 패치 후 "새 버전 등록 → 추출 → 저장소 적재 → 차이 검토(L1/L2/L3) → lock 갱신 → 앱 데이터 동기화 → 배포 스냅샷·릴리스 빌드"를 순서가 고정된 체크리스트로 실행하고 기록한다.

쉬운 말로: 게임이 업데이트될 때마다 사람이 손으로 하던 "자료 다시 뽑고, 그림 경로 맞는지 보고, 배포본 만들기"를 한 창에서 버튼과 점검표로 하는 도구다.

## 경계 (바꾸지 않는 것)

- 저장소 쓰기는 **저장소 자체 도구**(`register_client.py`, `import_extract.py`, `make_lock.py`, `verify_lock.py`, `diff_versions.py`)만 통해서 한다. 이 도구는 그 스크립트를 호출하고 결과를 보여 줄 뿐, 저장소 파일을 직접 쓰지 않는다. 단일 쓰기 원칙은 "쓰는 주체 = 사용자 PC에서 실행되는 이 도구(+오케스트레이터)"로 유지하고, 워커 세션은 저장소에 쓰지 않는다.
- 키·원본은 저장소 밖(`%USERPROFILE%\ba_jp_key.txt`)에 있고 도구는 값을 표시·기록하지 않는다. Steam 키 경로는 폐쇄(`docs/tactic-editor/t4a-steam-key-route-assessment-2026-10-08.md`) — KR 전용 자료는 키 불필요 파일(Excel.zip·카탈로그·번들)과 기존 수동 입력값에서만 온다.
- 게임 프로세스 후킹·메모리 읽기·주입 없음. 게임 파일은 읽기만, 복사는 해시 manifest로 대체.
- `backend/core/student_meta_data.py`는 생성 파일(AGENTS.md). 도구가 쓰되 손으로 고치지 않는다.
- Flutter는 저장소·프로필 파일을 직접 읽지 않는다(기존 developer_tools JSON stdin/stdout 경계 유지). [@devtools-migration] [@devtools-backend]
- 다섯 데이터 버킷 분리, runtime UI asset과 recognition template 분리 유지.
- 배포 결정(2026-09-27) 유지: 게임 이미지는 저장소·배포본에 넣지 않고 첫 실행 때 사용자 설치본에서 키 불필요 파일만 추출; 키가 필요한 표는 배포자가 패치마다 갱신하는 **스냅샷**으로 동봉.
- 이 워크플로는 택틱·프론트 개편과 **별도 레인**이다. 겹치는 파일(`developer_tools.py`, `developer_tools_main.dart`, `backend/data/*`, `data/extracted/pipeline/*`)은 M 세션만 수정하며, 프론트 개편의 FB-11b/FE3-g는 저장소 읽기 경로가 생기면(M3) 그 경로로 갈아탄다.

## 단계

| 단계 | 결과 | 선행 |
|---|---|---|
| M0 | 출처 지도·자산 매핑 inventory·계약 2개 | 없음 |
| M1 | 백엔드 저장소 reader + developer_tools 메서드 + 테스트 | M0 |
| M2 | devtools `--tool=metadata-manager` 창(뷰어·출처·자산 탭) | M1 |
| M3 | canonical 메타데이터·선물 친화도를 저장소 kind에서 재생성, SchaleDB 코드 제거 | M1 |
| M4 | 자산 매핑 검증 실행기(저장소 버전 + 사용자 설치본) | M0, M2 |
| M5 | 업데이트 관리자(패치 체크리스트 실행·L1/L2/L3 검토·lock 갱신·동기화) | M3, M4 |
| M6 | 배포 관리자(스냅샷 번들·첫 실행 추출 명세·릴리스 빌드·변경 기록) | M5 |

M1·M3은 병렬 가능(파일: M1은 `core/client_data_store.py`+devtools 메서드, M3은 export/sync 스크립트). M2와 M4는 M1 뒤 병렬.

### M0 — 출처 지도와 계약

- **필드별 출처 지도** `docs/metadata-manager/metadata-source-map-2026-10-XX.md`: canonical 메타데이터·스탯 카탈로그·선물·폼·서버 상태의 **필드마다** 현재 출처(SchaleDB / 수동 / `data/extracted` / 생성) → 저장소 kind·표·필드 후보 → 대체 가능/불가/보류. KR 전용 필드(한국어 이름·KR 출시 여부·KR 전용 폼)는 Steam 키 폐쇄를 전제로 "키 불필요 파일에서 가능한지"를 표마다 적는다.
- **자산 매핑 inventory**: UI asset 1,045개 + recognition entry 780개를 주소 키·번들·텍스처 이름으로 역추적해 `backend/data/asset_map/v1/asset-map.json`(contract `contracts/asset-map-v1.schema.json`) 초안. 역추적 불가 항목은 `source: manual` + 사유. [@asset-connection] [@game-assets]
- **메타데이터 출처 계약** `contracts/metadata-provenance-v1.schema.json`: 값 + `{kind, versionId, table, rowSha, tool}`. M3부터 생성되는 모든 메타데이터 파일이 이 provenance를 품는다.
- 완료 조건: 두 schema와 inventory가 있고, 대체 불가 필드 목록이 사용자 결정 항목으로 정리돼 있다. 코드 변경 없음.

### M1 — 백엔드 reader와 도구 메서드

- `backend/core/client_data_store.py`: `ba-data.lock` 읽기, pin된 버전·kind 목록, extract 파일 열기(해시 검증 실패 시 예외), 저장소의 다른 버전 열거(읽기 전용), `diff_versions.py` 결과 파싱. 저장소 경로는 `BA_CLIENT_DATA_DIR`(기본 `C:\Users\brigh\ba-client-data`), 없으면 "저장소 미연결" 상태를 반환하고 기존 기능은 그대로 동작. 현재 pin·extract 버전과 해시 목록은 `ba-data.lock`에 고정되어 있다. [@data-lock]
- `developer_tools.py` 메서드(버전 JSON 계약 유지): `store_status`, `store_versions`, `store_diff(from,to)`, `metadata_source_view(student_id)`(값 + provenance + 출처별 비교), `asset_map_list`, `asset_map_check(scope)`.
- 테스트: 임시 저장소 fixture(소형 버전 2개)로 lock 검증·해시 불일치·버전 섞기 거부·diff 파싱.
- 완료 조건: 전체 Python 녹색, 기존 developer_tools 메서드 동작 불변(기존 테스트 통과).

### M2 — 도구 창

- `developer_tools_main.dart`에 `--tool=metadata-manager` 추가. 기존 `student-metadata` 편집기는 **그 안의 첫 탭으로 흡수**하고 런처 `run_student_metadata_editor.cmd`는 새 도구로 바꾼다(기존 이름은 한 릴리스 동안 alias). [@devtools-entry]
- 탭: ① 학생(기존 편집기 + 출처/버전 열 + "이 값은 어디서 왔나" 패널) ② 출처(저장소 연결 상태, lock의 pin, 최신 버전과의 차이, kind 목록) ③ 자산(M4 결과 표, 필터: 누락/이름 변경/해시 변경/수동) ④ 업데이트(M5) ⑤ 배포(M6). ④⑤는 M2에서 자리만 만든다.
- UI는 v7 kit(`ui/kit`)만 쓴다. Flutter golden은 devtools 범위 밖(기존 관례).
- 완료 조건: `fe_gate.ps1` GREEN, 세 탭이 실제 Python 메서드로 채워짐, mock 모드에서도 열림.

### M3 — 출처 전환

- 현재 `export_canonical_metadata.py`는 생성된 `student_meta_data.py`를 canonical catalog로 내보낸다. [@canonical-export] 이를 **저장소 kind → canonical catalog** 방향으로 확장: 학생 식별·학교·역할·무기·선물 태그·선물 목록·친화도를 JP ExcelDB kind(`exceldb-json` 16표 + 필요 시 추가 표: 선물·친화 태그 표)에서 생성, 기존 값과 필드별 diff를 **미리보기 → 적용**(기존 SchaleDB 화면과 같은 2단계). 수동 전용 필드(KR 출시 여부·인식용 템플릿 이름 등)는 보존.
- 현재 `sync_student_stats_from_extracted.py`는 extracted의 스탯 catalog/formula를 검증·동기화한다. [@stats-sync] 저장소 kind 경로를 받도록 1옵션 추가(`--from-store`), 기존 경로도 유지.
- SchaleDB 화면·메서드·provider·merge paths 제거(결정 2). 제거 직전에 SchaleDB 유래 값을 동결해 저장소 재생성 결과와 비교(차이 0 또는 사유 목록)한 뒤 삭제.
- 모든 생성물에 provenance(M0 계약) 기록. `student_meta_data.py`는 생성 경로로만 갱신.
- 완료 조건: 저장소 기준 재생성 결과가 현재 canonical 값과 **차이 0 또는 사유가 적힌 차이 목록**(사용자 승인 전 적용 금지), 기존 parity fixture 통과, 전체 Python 녹색.

### M4 — 자산 매핑 검증

- 검사 대상 두 개: (a) 저장소에 등록된 버전의 카탈로그 스냅샷(JP `catalog_Remote.json`, Steam `catalog_Windows.bytes` — 키 불필요, 저장소 kind `addressables-catalog`로 적재), (b) 사용자 PC의 현재 Steam/JP 설치 폴더(읽기 전용, 경로는 설정값).
- 항목마다 판정: `ok` / `missing-key` / `bundle-renamed` / `bundle-hash-changed` / `texture-missing` / `manual`. 결과는 `debug/metadata_manager_asset_check_<stamp>/report.json` + 탭 ③.
- 첫 실행 추출(배포본의 클라이언트 측 추출)이 쓰는 목록은 이 asset-map의 `ok` 부분집합이어야 한다 — M6의 입력.
- 완료 조건: 현재 등록 버전 2개에 대해 보고서 1회, `manual`과 실패 항목 목록이 사용자 결정 항목으로 정리.

### M5 — 업데이트 관리자

- 탭 ④는 **패치 체크리스트 실행기**다. 단계마다 기존 스크립트를 그대로 호출하고 로그·종료 코드·산출물 해시를 기록한다. 임의 순서 실행 금지(선행 단계 녹색이어야 다음 버튼 활성).
  1. 설치본 버전 확인(`game-launcher-config.json` 등) → 저장소에 이미 있으면 중단.
  2. 키 확인(JP: `get_jp_key.py` 절차, 값 비표시; Steam: 폐쇄 — 키 불필요 추출만).
  3. `register_client.py` 새 version-id.
  4. 추출 kind 전수(`extract_jp.py` 표 목록, 스탯·전투·모션·favor-cafe·카탈로그) → `import_extract.py`.
  5. `diff_versions.py` 이전 pin ↔ 새 버전: L1(파일 해시) / L2(표 행 추가·삭제·변경 수) / L3(동작 변경 — 택틱 워크플로 판정 필요) 표. L3 후보가 있으면 여기서 멈추고 택틱 오케스트레이터 로그에 항목을 쓴다.
  6. 사용자 승인 → `make_lock.py`/`verify_lock.py --check-client` → M3 재생성·M4 검사·`sync_student_stats_from_extracted.py --from-store`.
  7. 전체 Python + `fe_gate.ps1`.
- dry-run 모드(아무것도 쓰지 않고 단계별 예상 변경만 표시) 필수.
- 완료 조건: 현재 버전에 대해 dry-run 1회 + "이미 등록됨" 중단 경로 확인; 실제 패치 1회는 다음 게임 업데이트 때 검증(별도 gate, 이 워크플로 완료 조건 아님).

### M6 — 배포 관리자

- 탭 ⑤: (i) **스냅샷 번들** — 키가 필요한 표에서 나온 배포용 파일(희귀도·분류·이름표 등 `backend/data/*` 생성물)을 lock의 version-id·해시와 함께 묶고 `release/.ba_planner_data_snapshot.json`에 기록. (ii) **첫 실행 추출 명세** — M4 `ok` 항목만으로 `release/first-run-extract-spec.json` 생성(주소 키·번들·텍스처·기대 해시). 클라이언트 측 추출 구현 자체는 프론트 개편 레인(FE)의 slice로 넘기고, 이 워크플로는 명세와 검증기만 소유. (iii) 릴리스 빌드 — 기존 `build_windows_release.ps1`/`sync_windows_release.ps1 -CheckOnly` 호출. (iv) 변경 기록 — 데이터 버전·lock 해시·L2 요약·앱 버전을 `release/CHANGELOG-data.md`에 append.
- 완료 조건: 현재 pin으로 스냅샷·명세·빌드 1회, `-CheckOnly` 통과, 변경 기록 1건.

## 세션 운영

- 레인 이름 `metadata`, 로그 `almanac/workflows/metadata-manager-orchestrator-log.md`, 상태 `metadata-manager-status.md`(단계별 상태·결정·산출물·검증·다음 행동; p0-p6 status와 같은 형식).
- 워커 프롬프트 앞에 공통 전문(`o3-holdout-session-prompts-2026-10-02.md`)을 붙이고, 저장소 쓰기 단계는 워커가 **명령을 준비만** 하고 사용자 PC에서 실행한다(`import_extract` 등; W4 선례).
- 완료 선언은 단계별 완료 조건으로만 한다. "SchaleDB 제거"·"첫 실행 추출 구현"·"실제 패치 검증"은 이 워크플로 밖의 후속이다.

## 사용자 결정 (2026-10-08 09:06, 확정)

1. KR 전용 필드 출처: **(a)** 키 불필요 파일 + 수동값 유지. JP 값으로 대체하지 않는다.
2. SchaleDB 화면: **즉시 제거**. M3에서 `metadata_schaledb_*`·merge paths UI·`schaledb_provider` 의존을 걷어내고, 선물·친화도는 저장소 kind에서만 온다. 제거 전에 현재 SchaleDB 유래 값을 한 번 동결(`debug/metadata_manager_schaledb_final_<stamp>/`)해 M3 재생성 결과와 차이 0을 확인하는 용도로만 쓴다. `core/schale_merge_paths.py`는 그 비교가 끝난 뒤 삭제.
3. 통합 방식: 기존 편집기를 새 도구의 탭으로 흡수. 조건 — **개발자 도구는 배포본에 포함되지 않는다**: `release/ba_planner_v7.exe`·`release/backend/`에 `developer_tools.py`·`developer_tools_main.dart`·저장소 reader의 쓰기 경로가 들어가지 않도록 M2에서 릴리스 번들 포함 목록을 검사하는 테스트 1개를 둔다(기존 `release/developer_tools/` 별도 번들은 유지).
4. 첫 실행 추출(클라이언트 측) 구현: **(a)** 프론트 개편 레인. 이 워크플로는 명세(`first-run-extract-spec.json`)와 검증기만 소유.
