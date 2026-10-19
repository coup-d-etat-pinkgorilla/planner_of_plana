---
title: "Metadata Manager Workflow Status"
summary: "metadata-manager-workflow.md M0~M6의 단계별 상태·결정·산출물·검증·다음 행동 기록입니다."
topics: [workflow, status, data, tooling]
sources:
  - id: workflow
    type: file
    path: almanac/workflows/metadata-manager-workflow.md
---

# Metadata Manager Workflow Status

M0~M6의 단계 정의와 완료 조건은 메타데이터 관리자 워크플로를 따른다. [@workflow]

| 단계 | 상태 | 비고 |
|---|---|---|
| M0 출처 지도·계약 | 기존 산출물 수신 검증 완료(2026-10-10, XB) | 기존 커밋 `8b880441`, canonical 5/5 및 인계 manifest 21/21 크기·SHA 일치. M4 실물 검증과 구분 |
| M1 백엔드 reader | 미착수 | M0 뒤 |
| M2 도구 창 | 미착수 | M1 뒤 |
| M3 출처 전환 | 미착수 | M1과 병렬 가능 |
| M4 자산 매핑 검증 | 미착수 | M0·M2 뒤 |
| M5 업데이트 관리자 | 미착수 | M3·M4 뒤 |
| M6 배포 관리자 | 미착수 | M5 뒤 |

## 결정 기록
- 2026-10-08 09:06 사용자: ① KR 전용 필드는 키 불필요 파일+수동값 ② SchaleDB 즉시 제거 ③ 편집기 흡수, 단 개발자 도구는 배포본에 없을 것 ④ 첫 실행 추출 구현은 프론트 레인.
- 2026-10-08 사용자: 워크플로 신설. 메타데이터 관리 도구(v6~v7 SchaleDB 크롤링 편집기 계승)를 공용 저장소 기반으로 만들고 업데이트·배포 관리자를 통합한다.

## 전제 상태 (2026-10-08)
- 공용 저장소 등록 버전: `jp-1.73.0-e2baf70e`, `steam-r464491-bbe68ad3`. v7 `ba-data.lock` 2 pins/16+ extracts, 읽기 경로 전환 미실시.
- 기존 도구: `developer_tools.py`(metadata_*·SchaleDB preview/apply·merge paths·items·template), `developer_tools_main.dart --tool=student-metadata`, `sync_student_stats_from_extracted.py`, `export_canonical_metadata.py`, `asset_spec/`(카탈로그 파서·번들 추출 참고 구현).
- Steam 키 경로 폐쇄(W1). KR 전용 자료는 키 불필요 파일·수동값만.

## 2026-10-10 XB 이관 수신

- 근거: `debug/xb_intake_m0_s4c6_20261010/output.md`, 원 인계 `debug/five_followup_approved_resume_20261008/m0/output.md`. 부모가 새 인계 artifacts 4개의 크기·SHA를 직접 확인했다.
- 이미 반영된 M0 커밋은 `8b8804410293232bfccc162a2a8a2647d7d8cb63`. 새 결과를 생성하거나 기존 파일을 변경하지 않았다. 현재 주요 파일 5개와 원 인계 복사본이 일치하며 manifest 21/21도 일치한다.
- 기존 검증 수치: 필드 141개(수동 89/대체 44/추출 필요 8/보류 0); 자산 1,831개(UI 1,045/recognition 786), 주소 해석 1,093/manual 738. 요청 recognition 780 대비 +6은 기존 정합 설명을 유지한다. schema 2개/negative 15개 통과는 원 검증 기록이며 이번에는 bytes/SHA 및 JSON 문법만 새로 확인했다.
- 물리 bundle/texture/crop 및 등록 snapshot은 M4에서 검증한다. M1~M6 상태는 미착수이며, 이번 XB 세션에서는 CF의 FB 요청을 우선 처리한다. M3에는 `student_bond_data.py` 출처 전환도 포함하며, A2 등록은 CF의 도구 목록 변경으로 요청한다.
