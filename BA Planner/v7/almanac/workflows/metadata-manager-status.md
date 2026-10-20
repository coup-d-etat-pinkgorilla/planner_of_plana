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
| M1 백엔드 reader | 기본 조회 커밋 완료, 실제 출처 비교 후속 | `1fbc4ddd` exact18(M1 10+storetools8). same-source CF20261011_171338 GREEN·focused85·whole1169/1509.032s·annotation16 PASS. WIP 보존/push0 |
| M2 도구 창 | CF 연결 커밋 완료·native 별도 검증 잔여 | CF `d2a53fed`/gate220445. 과거 별도 bundle symlink 실패는 보존; 전체 native 완료 미선언 |
| M3 출처 전환 | CLI4 커밋·승인5필드265 readonly 일치 | crosswalk v1/1325 fields diff0·stats2 exact. gift-affinity pin/R-M3-2 공식식/전체제거비교 BLOCKED(null), 제거선언CM |
| M4 자산 매핑 검증 | 실물 매핑·FD181 UI 추출 후속 | CF F5 요청 수신, manual449 포함 원본→UI 규칙/첫 실행 명세 검증 필요 |
| M5 업데이트 관리자 | 현재2pin readonly dry-run·이미등록중단 확인 | Product runner/UI·설치본새patch검증은별도. 실제쓰기단계는CM승인+사용자실행 |
| M6 배포 관리자 | X1 source8 검증완료·선택커밋준비 | 표준Python1422·집중26 PASS, snapshot/latest/app-data ZIP 형식. 실제alpha/런처/추출명세/native는후속 |

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

## 2026-10-20 13:24 — XB X1 M6·X4 계약 source11 검증 시작 준비

- X1 새snapshot/latest/ZIP 도구7과 X4 FD182 forward계약4를 격리집중18 PASS 뒤 신규경로로만 반영했다. 기존runtime/IPC/인식/CF source변화0, commit/push0. actualmain표준Python전체를 거쳐 별도커밋한다.
- 이번 X4는 계약고정/Mock착수용이며 runtime/replay/비정상종료정리 구현완료가 아니다. Dart사전목록은CF로그에게시했다. M6 실제alphaZIP/자동런처/FD181이미지제거·M4 first-run명세/전체P0-P6/native도 미완료다.
- M3 승인규칙·student-stats20extract lock수신, 공용store/lock/data-extracted쓰기0. M5readonly→M3는두필수목표뒤다. X5/X6/X7 미착수. 근거debug/xb_m6_x4_20261020/artifacts/applied.json.

## 2026-10-20 13:30 — XB M5 현재 pin dry-run·M3 승인 crosswalk readonly 진전

- **M5**: 현재 lock의 JP/Steam 2 pins·20 extracts 대상으로 reader.versions를 읽어 모두 already_registered로 확인하고 step1에서 중단했다. Step2(key)~7은 실행0. Store client manifests/lock 전후SHA불변·store/lock쓰기0. 설치본현재버전은새로조회하지않았고 “pin 대상 rehearsal”로한정한다. Product updater/checklist UI runner·실제patch 검증은미구현/미검증이다. 근거 artifacts/m5-dry-run.json.
- **M3**: R-M3-1 `1666aa56` 연구보고와 CM10-19 22:30 승인 규칙을 수신했다. 현재lock+canonical SHA에 바인딩한 **crosswalk v1**을 새로작성하고 JP에확인된school/attack/defense/role+weapon5개를 검증했다. 후보265/verified265·투영1325·selected field difference0. 이 값은 **부분 필드 preview**이며 독립Schale제거차이0이 아니다. Canonical/generated/provider쓰기0이다.
- 최초대조는 rarity의source정수와canonical문자열차이 때문에265개를보류로기록해 보존했다. 새 reviewed대조는 그 필드를변환하지않고 미투영/수동보존한다. 기존형식을정수로자동변경하지않았으며CM필수4항목검증을무효화하지않는다. Crosswalk/preview 최종파일은 m3-crosswalk-v1-reviewed.json·m3-readonly-preview-reviewed.json·m3-readonly-result-reviewed.json.
- **student-stats**: 새kind의catalog/formula DTO검증과실제 `--from-store student-stats --dry-run` exit0. 두문서가현재backend/data판과exactbytes동일하다. 실제sync/lock교체0.
- **M3 남은 차단**: gift-affinity가현재lock에미포함(사용자import/CMlock갱신필요); R-M3-1은공식gift exp/tag배율미확정이고CM-R R-M3-2대기; gift 태그7차이·rarity표현형식·전체재생성parity판정필요. 기존CLI의고정blocked reason중“crosswalk미승인”은이번승인으로해소됐으나효과적인blockers는별도receipt에기록했다. 독립제거비교는계속BLOCKED/diff=null, SchaleDB제거선언CM.
- **X1 실제 metadata preview**: 새M6코드로현재2pins/20kinds·runtime data14파일스냅샷을debug안에만생성하고새schema검증했다. SHA256 2b596ec8fd206f26f4336f2b960816ae63cd1ce3ceced18a1625e27b5cd95ea7. 실제release/ZIP/native게임수용·GitHub업로드0, 앱전체배포는FD181정리/배포런처등후속뒤다.
- X1/X4 main표준Python전체는진행중이며끝나기전PASS/커밋을선언하지않는다. Main source11추가수정0·frontend/lib/store/lock/data-extracted쓰기0·X5/X6/X7착수0. 근거debug/xb_m6_x4_20261020/artifacts/.

## 2026-10-20 14:33 — XB X1 M6·X4 계약 검증 완료·선택 커밋 준비

- **X1 source8**: M6 snapshot/latest/ZIP manifest schema3, offline app/data 포장기, fixture/test/설명문서 준비 완료. latest는 요구6키에schemaVersion/releaseType/dataSnapshotSha256을더해교체범위/같은게임pin의재생성을구분한다. Source/Dart현재IPC변화0. current metadata preview 2pins/20kinds·data14파일과schema검증, 합성data ZIP1695B를debug에보존했다. 실제alphaZIP/자동업데이트런처/첫추출명세/native수용/업로드는후속이다.
- **X4 source5**: FD182 임시연습계정create/current/reset/end/recover의forward schema/fixture/doc/test, is_practice선택불리언읽기·가상target tutorial:1280x720·기존scanner event/review/commit재사용계약을확정했다. 커밋전CF로그에RepositoryProfile/서비스/Process/Mock/controller/test변경목록게시완료. **runtimeImplemented=false**, 이번계약으로CF Mock착수가능·실제연결은후속runtime/paired gate뒤다.
- **검증**: 실제main표준 `py -3.11 -m unittest discover -s tests -v` **1422/1399.406s OK**, 실패/오류/skip0·보호입력4126변화0. 경로보강후집중26/1.935s PASS, Almanac/diff/cached-diff PASS·index empty. 첫도구패키지준비import실패와700.219s/684.203s중단전체(registry FAIL1 포함)와v3 1355/errors5(global openpyxl 누락)는원본FAIL/미완료로보존했다. 새source12전체를표준명령으로다시검증했고timeout/skip/exclusion/golden완화0이다.
- **선택진행**: M5 현재2pin/20extract readonly rehearsal에서already_registered step1중단확인, store/lock/설치본probe쓰기0. M3 CM승인5필드265명/1325개선택diff0·student-stats두파일exactbytes·DTO/dryrunPASS. Rarity형식은변환하지않았다. CM13:40등급재생성승인수신, ConstCommon소비금지·exp분모제외. Gift kind import/새lock미수신·독립전체비교미실시로제거diff=null/BLOCKED; Schale제거선언CM.
- **보존/다음**: 기존인식/C6/config/CF WIP·공용store/live lock/data-extracted/frontend/lib수정0. X5/X6/X7미착수. X1→X4 exact소스와XB자기log/status만선택커밋·push0, 그뒤CF/CM에해시회신한다. CM이정한다음slice는F2(a~f), F5는사용자확인전보류다. 기존extract icons progress는bundle수라는메모를CF에전달했다.
- 근거: debug/xb_m6_x4_20261020/output.md, source12/SHA·whole-v4.log/receipt·metadata/crosswalk·문서검사·합성zip은같은artifacts/. 커밋receipt는별도debug/xb_m6_x4_commits_20261020/에남긴다. 전체M6/M3/FB/P0-P6/native완료선언0.
