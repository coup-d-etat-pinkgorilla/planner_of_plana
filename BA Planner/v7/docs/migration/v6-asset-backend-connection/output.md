# v6 image/template migration and backend connection output

## 구현 결과

- `backend/assets/recognition/v1/manifest.json`에 총 780개 runtime entry를 등록했다.
  - 학생 template 254
  - inventory fast-icon template 497
  - inventory count glyph 10
  - ROI와 tactical lobby fixture 19
- 각 v6-derived recognition entry에 `source_path`, byte size와 SHA-256을 기록했다.
- `RecognitionAssetCatalog` 기본 root를 Python 소스 내부 경로에서 versioned backend asset
  경로로 변경하고 `BA_PLANNER_RECOGNITION_ASSET_DIR` override를 연결했다.
- template matcher는 원본 비교 의미를 유지하면서 보관 이미지를 96×96로 정규화해 전체
  catalog의 약 392MB decoded RGB 상주 비용을 줄였다.
- 넓어진 catalog가 검은 capture padding을 낮은 margin 후보로 오인하지 않도록 visible-content
  gate를 추가했다. 불확실한 실제 항목은 기존처럼 review 대상으로 남는다.
- Flutter에는 v6 원본과 byte-identical한 표시용 asset 1,045개를 검증해 등록했다.
  상세 source/destination/hash 목록은 `ui-assets-v1.manifest.json`에 있다.

## 경계

Flutter는 recognition manifest나 template을 읽지 않는다. Python backend는 Flutter asset을
읽지 않으며, scanner catalog의 version/hash readiness를 통과한 인식 자산만 사용한다.
현재 Windows release는 여전히 Python runtime/backend bundle을 포함하지 않으므로 backend
asset 배포 패키징은 별도 후속 단계다.

## 검증

- UI source/destination 1,045개 SHA-256 일치
- recognition manifest 780개 size/SHA-256 검증
- Python 전체 119 tests 통과
- Flutter 전체 217 tests와 `flutter analyze` 통과
- `flutter build windows --release` 통과
- `tools/verify_v6_asset_migration.ps1` 통과
- `codealmanac validate`, `codealmanac health`, `git diff --check` 통과
