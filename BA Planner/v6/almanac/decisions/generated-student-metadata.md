---
title: "Generated Student Metadata"
summary: "대규모 학생 메타데이터는 동기화 도구로 관리하고, 런타임 조회 API와 데이터 생성을 구분합니다."
topics: [data, refactoring]
sources:
  - id: student-meta
    type: file
    path: core/student_meta.py
  - id: student-meta-data
    type: file
    path: core/student_meta_data.py
  - id: student-meta-types
    type: file
    path: core/student_meta_types.py
  - id: sync-command
    type: file
    path: tools/sync_student_skills_from_schaledb.py
  - id: metadata-writer
    type: file
    path: tools/student_meta_tool.py
  - id: schaledb-sync
    type: file
    path: tools/schaledb_sync.py
---

# Generated Student Metadata

`core/student_meta.py`는 기존 호출자가 사용하는 안정적인 런타임 조회 API입니다.
대규모 생성 레코드와 서버 집합은 `core/student_meta_data.py`에, TypedDict와 편집 필드
계약은 `core/student_meta_types.py`에 둡니다. 조회 API는 생성 데이터를 다시 내보내므로
기존 `core.student_meta.STUDENTS` 호출도 유지됩니다. [@student-meta]
[@student-meta-data] [@student-meta-types]

SchaleDB에서 가져오는 필드와 스킬 필터는
`tools/sync_student_skills_from_schaledb.py`를 통해 갱신합니다. 이 명령은
`tools/schaledb_sync.py`의 매핑과 `tools/student_meta_tool.py`의 writer를
사용하며 writer는 `core/student_meta_data.py`만 다시 씁니다. 대량 데이터 변경은
동기화 매핑, data assignment, 조회 API reload 계약을 함께 확인해야 합니다.
[@sync-command] [@schaledb-sync] [@metadata-writer]

## 불변식

- 현재 레벨, 성급, 장비, 스캔 수량처럼 자주 변하는 값은 정적 메타데이터에 넣지
  않습니다.
- 새 필드는 누락되어도 기존 학생 레코드가 동작하도록 optional-safe하게 읽습니다.
- 정기적으로 편집할 필드는 동기화 매핑뿐 아니라 메타데이터 편집 도구의 옵션과
  writer도 갱신합니다.
- 에셋 업데이트에는 조회 API가 아니라 `core/student_meta_data.py`를 포함합니다.
- 이전 에셋의 `assets/core/student_meta.py`도 읽을 수 있게 legacy fallback을 유지합니다.
- 새 레코드·기존 필드 값은 에셋 업데이트로 전달하지만, 타입·조회 API·새 필드 소비
  코드가 바뀌면 앱 업데이트도 필요합니다.
- 모듈화 이전 앱은 `student_meta_data.py`를 읽지 못하므로 최초 형식 전환은 새 loader가
  포함된 앱 업데이트를 선행합니다. legacy fallback은 새 앱에서 옛 에셋을 읽기 위한
  단방향 호환입니다.
- 대량 수동 편집 대신 dry-run과 스키마 검사를 먼저 사용합니다.

메타데이터를 UI 필터나 통계에 노출할 때는
[Data Bucket Separation](data-bucket-separation)의 분류를 유지합니다. 파일 분리는
[Large Module Change Safety](../gotchas/large-module-change-safety)의 영향 범위 절차를
거친 뒤 진행합니다. 생성 데이터가 클라이언트에 도달하는 경로는
[Student Metadata Delivery](../flows/student-metadata-delivery)를 따릅니다.
