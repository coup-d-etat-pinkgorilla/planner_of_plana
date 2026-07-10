---
title: "Student Metadata Delivery"
summary: "생성된 학생 메타데이터가 에셋 릴리스에 포함되고 클라이언트 시작 시 다운로드·검증·로딩되는 흐름입니다."
topics: [data, architecture]
sources:
  - id: startup
    type: file
    path: main.py
  - id: asset-manager
    type: file
    path: core/asset_manager.py
  - id: metadata-api
    type: file
    path: core/student_meta.py
  - id: metadata-data
    type: file
    path: core/student_meta_data.py
  - id: student-update-helper
    type: file
    path: tools/prepare_student_asset_update.py
  - id: release-builder
    type: file
    path: tools/build_beta_release.py
  - id: release-publisher
    type: file
    path: tools/publish_beta_release.py
  - id: update-wizard
    type: file
    path: tools/update_wizard.py
---

# Student Metadata Delivery

학생 레코드 값과 이미지처럼 코드 변경이 필요 없는 추가분은 앱 실행 파일이 아니라
에셋 업데이트로 전달합니다. 타입, 조회 동작, 새 필드 해석 방식이 바뀌면 에셋만
배포하지 않고 앱 업데이트도 함께 배포합니다. [@metadata-api] [@metadata-data]

## 생성과 게시

1. `tools/prepare_student_asset_update.py`가 SchaleDB 값을 기존 레코드에 병합하고
   `core/student_meta_data.py`의 `STUDENTS` assignment를 다시 씁니다. 학생 매칭,
   초상화, 엘레프 이미지도 각 template 디렉터리에 복사합니다. [@student-update-helper]
2. 이 도구는 `tools/build_beta_release.py --skip-exe`를 호출합니다. 전체 에셋 ZIP과
   `asset_manifest.json`을 만들고, 이전 manifest가 주어졌으면 변경 파일만 포함한
   patch ZIP도 만듭니다. manifest에는 버전, 다운로드 URL, 전체 ZIP SHA256, 파일별
   SHA256, 지원되는 `from`/`to` patch 목록이 들어갑니다. [@release-builder]
3. 버전 태그에는 ZIP과 manifest를 올리고, 이미 설치된 클라이언트가 새 버전을 찾도록
   동일한 최신 manifest를 안정 태그 `latest-assets`에도 올립니다. 버전 태그만 올리고
   `latest-assets`를 갱신하지 않으면 기존 클라이언트는 업데이트를 발견하지 못합니다.
   에셋 전용 릴리스는 `tools/update_wizard.py publish-assets`가 두 게시 작업을 함께
   처리합니다. `prepare_student_asset_update.py --github-release`의 직접 업로드는 버전
   태그만 갱신하므로 그것만 실행한 경우 `latest-assets`를 별도로 갱신해야 합니다.
   앱 ZIP도 함께 배포하는 전체 릴리스에서는 `tools/publish_beta_release.py`가 안정
   manifest까지 갱신합니다. [@update-wizard] [@release-publisher]

## 클라이언트 시작과 적용

`main.py`는 Viewer, Scanner, repository처럼 학생 메타데이터를 import하는 모듈보다 먼저
`ensure_assets_ready()`를 실행합니다. 따라서 정상 시작 경로에서는 다운로드와 설치가
끝난 뒤 처음으로 `core.student_meta`가 import됩니다. [@startup] [@asset-manager]

1. 실행 파일과 함께 제공된 base `asset_manifest.json`에서 안정 manifest URL을 읽고
   `latest-assets/asset_manifest.json`을 내려받습니다.
2. `%LOCALAPPDATA%/BA Planner/assets/current/installed_manifest.json`의 버전과 최신 버전을
   비교합니다. 동일하면 다운로드하지 않습니다.
3. 현재 버전에서 최신 버전으로 가는 정확한 patch 항목이 있으면 patch ZIP을 먼저
   내려받습니다. archive SHA256과 적용된 파일별 SHA256을 검증하고 삭제 목록도
   반영합니다.
4. patch가 없거나 다운로드·검증·적용이 실패하면 전체 에셋 ZIP으로 fallback합니다.
   전체 ZIP은 임시 디렉터리에 안전하게 풀고 `current.new`/`current.old` 교체를 거쳐
   설치하므로 정상 설치본을 중간 상태로 노출하지 않습니다.
5. 성공한 최신 manifest를 `installed_manifest.json`으로 기록합니다. 업데이트 검사는
   앱 시작 시 수행되며 실행 중인 프로세스에 메타데이터를 background hot reload하지는
   않습니다. [@asset-manager]

설치 후 `core.student_meta`는 실행 파일에 포함된 기본 data module을 먼저 읽은 다음,
`assets/current/core/student_meta_data.py`가 있으면 그 값을 우선 적용합니다. 새
클라이언트는 전환 전 에셋을 위해 `assets/current/core/student_meta.py`도 legacy
fallback으로 읽습니다. [@metadata-api]

## 모듈화 전환 불변식

- 새 레코드와 기존 필드 값만 바뀌면 `core/student_meta_data.py`를 포함한 에셋
  업데이트로 배포할 수 있습니다.
- `core/student_meta.py` 조회 API, `core/student_meta_types.py`, 필드 의미나 소비 코드가
  바뀌면 앱 업데이트가 필요합니다. 이 파일들은 일반 학생 데이터 에셋의 대체물이
  아닙니다.
- 모듈화 이전 실행 파일은 `student_meta_data.py`를 알지 못하고 legacy
  `student_meta.py`만 읽습니다. 따라서 새 파일 형식으로 전환하는 최초 릴리스는 새
  loader가 포함된 앱 업데이트를 먼저 설치해야 합니다. 새 loader의 legacy fallback은
  "새 앱이 옛 에셋을 읽는" 방향만 보장하며, "옛 앱이 새 에셋을 읽는" 역방향 호환은
  보장하지 않습니다.
- 최초 전환 앱이 충분히 배포되기 전에 `latest-assets`를 새 형식으로 바꾸면 구형 앱은
  이미지와 manifest를 받을 수 있어도 신규 학생 레코드는 사용하지 못합니다. 전환
  릴리스는 앱 업데이트 필수임을 명시하거나 별도 호환 에셋 전략을 사용해야 합니다.
- 신규 학생 한 명을 완성하려면 metadata record뿐 아니라 매칭 template, portrait,
  eleph 이미지가 같은 에셋 릴리스에 포함되어야 합니다.

메타데이터의 소유권과 writer 계약은
[Generated Student Metadata](../decisions/generated-student-metadata)를 함께 봅니다.
