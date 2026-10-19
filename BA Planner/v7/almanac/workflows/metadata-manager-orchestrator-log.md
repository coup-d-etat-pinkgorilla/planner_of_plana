---
title: "Metadata Manager Orchestrator Log"
summary: "메타데이터 관리자 M0~M6 워크플로의 오케스트레이터 결정과 배정 기록입니다."
topics: [workflow, data]
---

# Metadata Manager 오케스트레이터 로그

## 2026-10-08 09:00 — 워크플로 신설 (오케스트레이터)
- 사용자 요청: 메타데이터 관리 도구를 공용 저장소(ba-client-data) 기반으로 다시 만들고, v7이 보여 주는 학생별 메타데이터·assetbundle 매핑 유효성 확인·업데이트 및 배포 관리자를 한 도구로 통합.
- 작성: `metadata-manager-workflow.md`(M0~M6), `metadata-manager-status.md`. 레인 `metadata`는 택틱·프론트와 별도. 겹치는 파일(`developer_tools.py`, `developer_tools_main.dart`, `backend/data/*`, `data/extracted/pipeline/*`)은 M 세션만 수정.
- 조사 근거: README 독립 개발 도구 절, `docs/migration/developer-tools-migration.md`, `developer_tools.py` 메서드 목록(SchaleDB 7필드 가져오기·merge paths·asset status), `sync_student_stats_from_extracted.py`(이미 extracted 기반), `asset_spec/`(Addressables 카탈로그 → 번들 → Texture2D), `v6-asset-backend-connection`(UI asset 1,045·recognition 780), 배포 결정 2026-09-27(첫 실행 추출 + 스냅샷).
- M0 착수 전 사용자 결정 4개 대기(워크플로 말미).

## 2026-10-08 09:10 — 사용자 결정 4건 반영·M0 배정
- 결정: 1(a) KR 키 불필요+수동 / 2 SchaleDB 즉시 제거(동결 비교 후 삭제) / 3 흡수, 개발자 도구 배포본 비포함 테스트 추가 / 4(a) 첫 실행 추출은 프론트 레인. 워크플로 문서 갱신.
- M0 배정: `docs/metadata-manager/session-prompts-2026-10-08.md`. 다른 레인(택틱 W5b·W4b·S4-C6·A0, 프론트 Lane A)과 파일 겹침 없음(문서·contracts 신규·inventory JSON만).

## 2026-10-08 13:45 — 파일 소유 충돌 알림: 개발자 도구 진입점 (프론트 오케스트레이터 작성, 알림만)

- 택틱 과제 A(애니메이션 스펙트럼)의 A2는 "v7 개발자 도구 안의 Flutter 화면"이다. 프론트가 08:40에 적은 경계는 "새 폴더 + 개발자 도구 진입점 등록 1곳만 수정"이었다.
- 같은 날 메타데이터 관리자 워크플로(09:00)가 `developer_tools.py`, `developer_tools_main.dart`, `backend/data/*`, `data/extracted/pipeline/*`는 M 세션만 수정한다고 정했다. 또 "개발자 도구는 배포본에 없을 것"(결정 3)이 있다.
- 따라서 A2의 진입점 등록은 M 세션 소유 파일을 건드린다. 제안: A2 착수 전에 두 오케스트레이터가 정한다. ① M 세션이 진입점 1줄 등록을 대신하거나 ② M2 도구 창에 도구 등록 지점(목록 파일)을 두고 A2는 새 파일만 추가한다. 어느 쪽이든 배포본 제외 테스트에 A2 화면도 포함한다.
- A1 산출 경로(`data/extracted/animation-spectrum/`)는 `data/extracted/pipeline/*`(M 소유)와 다른 경로이지만, 추출 도구를 pipeline 아래에 두면 같은 충돌이 생긴다.
- 프론트 쪽은 이 결정에 따르기만 한다. 공용 위젯 키트 수정은 계속 프론트 로그로 요청한다.

## 2026-10-09 17:45 — 알림: FB-11b 인연 자료 스냅샷 (프론트 오케스트레이터 작성, 알림만)

- 프론트 개편 FB-11b(커밋 `7d0af068`)가 인연 경험치표(`FavorLevelExcel.ExpType`)와 카페 쓰다듬기 자료를 `backend/core/student_bond_data.py` 스냅샷(JP 1.73.0, 원본 sha 확인 스크립트 포함)으로 넣었다. 근거는 택틱 W4/W4b(`9d14b2b5`·`a107c3f2`).
- M3에서 자료 출처를 추출 파이프라인으로 바꿀 때 이 스냅샷도 대상이다. 계산 규칙(`core/student_bond.py`)과 계약(`planning-student-bond-v1`)은 그대로 두고 자료 공급만 바꾸면 된다. 바꿀 때 프론트 로그에 알려 주면 FB 쪽 회귀 fixture를 맞춘다.

## 2026-10-10 01:20 — 레인 간 결정 반영 (택틱 로그 01:20 항목 참조)
- 개발자 도구 진입점: 택틱 A2 화면(`frontend/lib/developer_tools/animation_spectrum/`)의 등록은 **M 레인이 1줄로 수행**. M2에 도구 목록 파일 `frontend/lib/developer_tools/tool_registry.dart` 신설을 추가(도구 1개 = 1줄). 배포본 제외 테스트는 `developer_tools/**` 전체 대상.
- `data/extracted/pipeline/extract_jp.py` TABLES 1회 변경(택틱 W5b, D8 승인)은 통지 수신. 그 외 pipeline 변경은 M 레인만.
- M3 출처 전환 대상 추가: `backend/core/student_bond_data.py`(프론트 FB-11b가 넣은 인연 경험치·카페 스냅샷, W4/W4b 근거 sha 포함).

## 2026-10-10 01:35 — 레인 교통정리 (클로드 마스터 작성, 전 레인 알림)

- 사용자 결정: **클로드 = 프론트(CF), 코덱스 = 백엔드·스캐너·택틱 구현·메타데이터 백엔드(XB, 신설), 클로드 마스터(CM, 이 세션) = 전체 계획·실험·택틱 연구·공용 저장소.** 규칙 원본 `almanac/workflows/lane-charter-2026-10-10.md`(레인·파일 소유·인계 규칙·gate·진행 중 항목 귀속표). XB 첫 프롬프트 `docs/orchestration/codex-master-orchestrator-prompt-2026-10-10.md`, XB 로그 `backend-orchestrator-log.md`(XB가 생성).
- 이관: S4-C6·O3-4·S-FB1b·S-FB2b·T-FB1b·T-FB2d·M0/M1/M3/M5/M6 백엔드 → XB. M2·탭 UI·A2 → CF. FB-1b·FB-2a는 CF 백엔드 워커가 커밋까지, 그 뒤 FB-* 백엔드는 XB.
- 레인 간 요청·회신은 상대 로그 끝 항목으로(사용자 중계 없이 각 오케스트레이터가 세션 시작 때 읽는다).

## 2026-10-10 03:27 — 알림(XB): M0 기존 산출물 수신 검증 완료

- XB 이관 시작 및 역할 기록: `almanac/workflows/backend-orchestrator-log.md`. M0 재배정 없이 기존 산출물을 받았다. 커밋 `8b8804410293232bfccc162a2a8a2647d7d8cb63`를 로컬 Git으로 확인했다.
- 수신 근거 `debug/xb_intake_m0_s4c6_20261010/output.md`: 원 manifest 21/21, 주요 canonical 5/5 크기/SHA 일치. 부모도 새 인계 artifacts 4개 크기/SHA를 확인했다. 필드141(수동89/대체44/추출8/보류0), 자산1831(UI1045/recognition786, 주소1093/manual738) 및 schema/negative 통과는 기존 검증 결과로 구분한다.
- metadata-manager-status의 M0 행과 수신 기록을 갱신했다. source-map 본문·canonical 데이터·workflow 결정은 바꾸지 않았다. M4의 물리 자산/등록 snapshot은 미검증이며 SchaleDB 제거 완료를 선언하지 않는다.
- FB 인계 왕복과 CM 계약 승인이 먼저다. M1/M3/M5/M6 백엔드는 XB, M2/탭 UI와 A2 도구 등록은 CF라는 헌장을 적용한다. M3에는 FB-11b student_bond_data 출처 전환을 유지한다. M1 착수 때 승인된 M0 파일을 그대로 입력으로 사용한다.
