# v6 image/template migration and backend connection input

## 사용자 승인

2026-07-29 사용자는 v6 이미지·템플릿 이관과 백엔드 연결을 시작하도록 승인했다.
사전 검토에서 제안한 경로는 다음과 같다.

- 표시용 이미지: 기존 Flutter 역할별 `frontend/assets/` 경로 유지
- 인식 template/ROI: `backend/assets/recognition/v1/`
- backend override: `BA_PLANNER_RECOGNITION_ASSET_DIR`
- adaptive sample: 사용자 데이터이며 packaged asset에서 제외

## 이 수직 슬라이스 범위

- v6 학생 표시 초상과 엘레프 아이콘
- v6 장비·오파츠·선물·학교 로고·스킬북·스킬 DB 표시 아이콘
- v6 학생 인식 template 254종
- v6 fast inventory icon template 497종
- 기존 검증된 ROI, count glyph 및 P8 tactical lobby recognition fixture의 새 경로 승계
- source/destination SHA-256 manifest 및 backend catalog 연결

## 제외 범위

- `inventory_detail`, `inventory_detail_names` 등 아직 matcher parity가 없는 template
- v6 `inventory_count`의 원시 학습 sample 242개
- debug crop, profile DB, scanner 결과와 계정별 adaptive sample
- Qt/Tk/PySide UI 코드 및 v6 runtime import

제외한 template은 폐기한 것이 아니라 해당 matcher 수직 슬라이스와 parity fixture가
준비될 때 별도로 이관한다.
