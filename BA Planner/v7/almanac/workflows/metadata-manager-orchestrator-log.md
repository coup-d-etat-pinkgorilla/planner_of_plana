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

## 2026-10-20 13:34 — 회신(XB): CM13:40 수신·F2 다음 순서·M3 차단 정정

- X1·X4 현재완료목표유지, 그뒤F2(a~f)프로토콜우선을수신했다. F5(UI449)는사용자확인전착수하지않는다. 현재X1/X4제품source11은전체Python진행중이라추가변경0이다. F2읽기전용다음slice메모만 artifacts/first-run-next-slice.md에준비했다.
- CM이학생태그/선물태그+현로컬규칙의친화도등급재생성을승인한것을수신했다. 앞13:30 보고의“gift태그7차이및공식tag배율미확정”을등급재생성전체의독립차단으로계속사용하지않는다. ConstCommon은canonical소비금지, exp_value는기존결정대로제거비교분모에서제외하며동결표보존제안의사용자확인회신을기다린다.
- 현재실행차단은gift-affinity의실제사용자import/live lock반영미수신과전체재생성/독립비교미실시다. 승인된crosswalk는현재20extract lock에재바인딩완료,265명5필드1325개선택diff0이다. Gift kind가등록되면다시새lock에바인딩해야한다. Canonical/Schale삭제0, 제거완료선언CM이다.
- F2추가발견:현재extract.progress의icons done/total은아이콘수가아니라**bundle수**다. “1,330개”를고정분모로쓰지않고실제manifest완료수와단위로계약을정할예정이다. 현재data/Steam캐시patch와JPdataVersion필드의신선도를혼동하지않는다. runtime/API확정이아닌사전조사다.
- 로그/문서기존WIP와CM13:40항목도보존하고XB소유log/status부분만선택커밋한다. stage/commit/push0, 실제새런처/firstalphaZIP/X4runtime/X5~X7완료주장0.

## 2026-10-20 14:33 — XB X1 M6·X4 계약 검증 완료·선택 커밋 준비

- **X1 source8**: M6 snapshot/latest/ZIP manifest schema3, offline app/data 포장기, fixture/test/설명문서 준비 완료. latest는 요구6키에schemaVersion/releaseType/dataSnapshotSha256을더해교체범위/같은게임pin의재생성을구분한다. Source/Dart현재IPC변화0. current metadata preview 2pins/20kinds·data14파일과schema검증, 합성data ZIP1695B를debug에보존했다. 실제alphaZIP/자동업데이트런처/첫추출명세/native수용/업로드는후속이다.
- **X4 source5**: FD182 임시연습계정create/current/reset/end/recover의forward schema/fixture/doc/test, is_practice선택불리언읽기·가상target tutorial:1280x720·기존scanner event/review/commit재사용계약을확정했다. 커밋전CF로그에RepositoryProfile/서비스/Process/Mock/controller/test변경목록게시완료. **runtimeImplemented=false**, 이번계약으로CF Mock착수가능·실제연결은후속runtime/paired gate뒤다.
- **검증**: 실제main표준 `py -3.11 -m unittest discover -s tests -v` **1422/1399.406s OK**, 실패/오류/skip0·보호입력4126변화0. 경로보강후집중26/1.935s PASS, Almanac/diff/cached-diff PASS·index empty. 첫도구패키지준비import실패와700.219s/684.203s중단전체(registry FAIL1 포함)와v3 1355/errors5(global openpyxl 누락)는원본FAIL/미완료로보존했다. 새source12전체를표준명령으로다시검증했고timeout/skip/exclusion/golden완화0이다.
- **선택진행**: M5 현재2pin/20extract readonly rehearsal에서already_registered step1중단확인, store/lock/설치본probe쓰기0. M3 CM승인5필드265명/1325개선택diff0·student-stats두파일exactbytes·DTO/dryrunPASS. Rarity형식은변환하지않았다. CM13:40등급재생성승인수신, ConstCommon소비금지·exp분모제외. Gift kind import/새lock미수신·독립전체비교미실시로제거diff=null/BLOCKED; Schale제거선언CM.
- **보존/다음**: 기존인식/C6/config/CF WIP·공용store/live lock/data-extracted/frontend/lib수정0. X5/X6/X7미착수. X1→X4 exact소스와XB자기log/status만선택커밋·push0, 그뒤CF/CM에해시회신한다. CM이정한다음slice는F2(a~f), F5는사용자확인전보류다. 기존extract icons progress는bundle수라는메모를CF에전달했다.
- 근거: debug/xb_m6_x4_20261020/output.md, source12/SHA·whole-v4.log/receipt·metadata/crosswalk·문서검사·합성zip은같은artifacts/. 커밋receipt는별도debug/xb_m6_x4_commits_20261020/에남긴다. 전체M6/M3/FB/P0-P6/native완료선언0.

## 2026-10-20 14:33 — 회신(XB): X1 M6 커밋 완료·X4 계약 커밋 준비

- **X1 M6 `cb6758d638a880ebf172db75f012b52438bbf765`**: 신규source8(포장기/test/schema3/fixture/doc)와XB자기log/status projection만포함했다. Exactcommit경로·blob SHA는commit task M6-receipt.json, working WIP·source12·lock보존·indexempty/push0이다.
- 실제main표준Python 1422/1399.406s OK·집중26·Almanac/diff PASS. Latest required6+schemaVersion/releaseType/dataSnapshotSha256 형식이커밋됐으므로이형식을기준으로CF 소비/업데이트UI를계획할수있다. 실제자동런처/firstalphaZIP/F2/native수용완료는아니다.
- 다음은X4 forward계약source5 별도커밋이다. 실제practice/replay runtime은미구현이며기존IPC/Dart 바이트변경0. 근거debug/xb_m6_x4_20261020/output.md 및 debug/xb_m6_x4_commits_20261020/artifacts/M6-receipt.json.

## 2026-10-20 14:33 — XB 보고: X1 M6·X4 계약 커밋 완료

- **완료 X1**: M6 snapshot/latest/ZIP 생성도구 source8 커밋 **`cb6758d638a880ebf172db75f012b52438bbf765`**. Lock2pins/20kinds·runtime data14파일 metadata preview, app/data zip·SHA·변경기록·latest출력, 신규schema3/fixture/test/문서가포함됐다. 소비형식은contracts/release-package-v1.md. 합성검토zip만생성했고실제alpha/native/자동업데이트런처/업로드는후속이다.
- **완료 X4 계약**: FD182 forward-contract source5 **`96319b3eefb8b0d719cdef6119ce967a64403dd8`**. repository.practice.create/current/reset/end/recover·is_practice·가상target/replay경계·수명계약, 커밋전Dart DTO목록CF게시완료. CF는이커밋으로Mock F3를진행할수있다. **Runtime미구현**·기존normalProfile/IPC/scannerproducer변화0; 실제RPC/replay연결은후속runtime 및same-source CFgate뒤다.
- **검증/보존**: 최종기존project .venv 의존성을사용한실제main표준Python **1422/1399.406s OK**, 집중26/1.935s+Excel89/5.533s PASS·Almanac/diff/cached-diff PASS. 첫import준비실패·경로보강전700.219s/684.203s중단전체(registry FAIL1 포함)와v3 1355/errors5(global openpyxl 누락)는원로그보존, 테스트/timeout/skip/golden완화0. 기존4114입력보존+최종source12불변(기존registry test1개계획변경), 다른레인문서WIP도HEAD+XB소유항목만indexprojection해보존, sourcecommits두개와자기문서마감커밋외push0. frontend/lib/store/lock/data-extracted쓰기0·키/게임프로세스/연구원본/Viewer/Arena/외부holdout접근0이다.
- **추가진전**: M5현재2pin already_registered readonly step1중단검증, 제품runner/실제patch는후속. M3 CM승인5필드265명/1325개선택diff0·새lock canonical SHA재바인딩·stats2 exact/DTO/dryrunPASS. Rarity표현변환0·canonical생성쓰기0. CM13:40등급재생성승인/ConstCommon금지/exp제외수신; gift kind사용자import/live lock새반영 및독립전체비교전제거diff=null/BLOCKED·Schale제거선언CM.
- **다음/제한**: CM13:40대로F2(first-run 추출a~f)다음, F5는사용자확인전보류. icons callback done/total은bundle단위이며1330고정아이콘분모로표시하면안된다는코드근거/후속메모를CF에전달했다. X5/X6/X7착수0, 전체M6/M3/FB/P0-P6/native완료주장0. 실제포장명령은커밋된문서에있으며firstalphaZIP은남은런처/F2/사용자수용후생성한다.
- **인계**: source검증봉인 debug/xb_m6_x4_20261020/output.md, 선택커밋/문서/WIP보존인계 debug/xb_m6_x4_commits_20261020/output.md. 기존sealed산출물은수정하지않았다.

## 2026-10-20 16:53 — XB X1-b/X1-c 검증 완료·선택 커밋 준비

- CM14:50 X1후속 offline source5완료: latest-app.json/latest-data.json 분리·app-first/exact-compatible-data 소비규칙·GitHub latest 게시시두descriptor carry-forward 의무, app-only --allow-bundled-ui-assets/manifest bool, approved GyeonggiTitle SHA+공식조건 notice 자동동봉. 기본UI거부/인식이미지/private/developer거부유지. 기존entry schema v1/runtime/IPC/Dart producer바이트변화0, 현재Dart필수변경0을CF사전게시했다.
- 격리focused22/0.888s·main registry6/1.129s PASS. 실제main표준Python **1428/1519.826s OK**, 보호4127입력추가변화0·Almanac45pages/diff/cached-diff PASS. 처음main을잘못import한sandbox준비errors17은원로그보존, timeout/skip/golden완화0이다.
- Gyeonggi공식출처 https://web1.gg.go.kr/contents/contents.do?ciIdx=679&menuId=2457 에서프로그램동봉허용/글꼴자체유상양도금지를확인하고요약notice를저장했다. Frontendasset수정0·실제alphaZIP/native/자동런처/업로드완료0. 기존WIP·store/live lock/data-extracted보존·push0.
- 다음F2 recognition-only 격리후속이진행중이다. F5는D-ALPHA-SPLIT에따라alpha2보류, M3exp동결표허용수신·giftkind새lock전재바인딩0. Source5/SHA/원로그근거 debug/xb_x1bc_f2_20261020/output.md, 후속commit receipt는 debug/xb_x1bc_commits_20261020/.

## 2026-10-20 16:53 — XB 보고: X1-b/X1-c 커밋 완료·F2 진행

- **완료 X1-b/X1-c**: `26b9df8a51b1c24853203435598295275b61d01e` source5+XB소유log/status만선택커밋. 독립 latest-app/latest-data endpoint·app-first·data정확호환·게시시양쪽유지, app-onlyalphaUI플래그/manifest bool, approvedpublicfont SHA/notice자동동봉. Entryv1/기존IPC/Dartproducer변화0.
- **검증**: main표준Python1428/1519.826s OK·격리22·registry6·Almanac45pages/diff/cached-diff PASS, 보호4127추가변화0·indexempty·push0. 실제alphaZIP/런처/native완료0, 기존인식/CF WIP와CM/CF문서보존. 근거 debug/xb_x1bc_f2_20261020/output.md 및 debug/xb_x1bc_commits_20261020/artifacts/receipt.json.
- **진행/다음**: F2 recognition-onlya~f를격리구현중. 새RPC/진행DTO·Dart목록/정확반영계획게시후같은소스CFgate뒤runtime커밋. F5alpha2보류. M3D-M3-EXP수신, giftkind새lock전crosswalk재바인딩0;store/live lock/data-extracted/frontend/lib쓰기0. Schale제거선언CM.

## 2026-10-20 17:04 — 정정(XB): F2 lock 변경 오판·동일 입력 재검증

- 이전메모20extract와현재21을비교해외부변경으로잘못판단했다. **실제저장preflight/applied 지문은이미21lock과동일하고변경0**이다. Fingerprint assert가false변경보고를막았고원래전체종료receipt도drift=[]다. CM이나다른레인의검증중변경을주장하지않는다. source14/보호4134·XBstore/lock쓰기0.
- XB소유testworker를153.703s시점에불필요하게중단했다. 최초전체는tests=null/FAIL_PRESERVED로원로그보존하며PASS로세지않는다. 같은입력/표준명령으로v2전체를재실행한다. 새입력재바인딩이아닌동일입력재검증이다. 입력지문대조가아닌오래된메모를판단근거로쓴것을정정한다.
- M3 D-M3-EXP의52선물exp동결표를debug격리에서준비했다(20값37개/60값15개·exp필드차이0), runtime/canonical/원천쓰기0. 봉인debug/xb_m3_exp_freeze_20261020/output.md의"gift pending"문구는실제comparison.json의21/gift_kind_pinned=true관찰과구별한다. 미수신은**CM알림**이며kind미포함주장이아니다. 이전봉인산출물은수정하지않는다.

## 2026-10-20 17:08 — XB M3 lock21 수신·exp 동결·격리 재생성 preview

- CM commit afd2bf94(14:46)에gift-affinity/lock21이이미고정된것을수신했다. 이전미래형로그의"새lock미수신"차단을이커밋근거로해소한다. 새crosswalk를현재21lock/canonical에**1회**바인딩했다. lock/store/native원본/키쓰기·접근0이다.
- **격리preview**: 학생265명/승인5필드1325차이0, 학생preferred/unique tag집합차이0, 선물52exp동결입력차이0. JPraw선물태그변경은7개로사유목록보존; 기존local규칙의학생×선물13780개 grade/exp_per_gift차이0. 임시ConstCommon소비0·공식식확정주장0. D-M3-EXP에따라R-M3-2를마무리차단으로두지않는다.
- **다음/제한**: artifacts/main-application-plan.md에저장소→canonical/generated구현, provider/alias/merge-path/tool삭제,CF Dart메서드/UI/Mock사전영향목록과같은소스gate계획을남겼다. 이번main재생성/코드삭제0·전체독립제거비교는아직null이다. F2main동결유지, Schale제거완료선언CM.
- 근거 debug/xb_m3_regenerate_20261020/output.md 및artifacts/reviewed-preview.json. 별도exp동결표 debug/xb_m3_exp_freeze_20261020/의52값은유효하되그output의pending문구는이수신으로정정한다(봉인파일수정0). 첫로컬helper inspect.py이름충돌은preparation-issue.txt에보존/수정후preview성공했다.

## 2026-10-20 17:22 — XB 보고: X1-b/c 커밋·F2 CF gate 요청·M3 격리 preview

- **커밋 완료**: X1-b/X1-c **26b9df8a51b1c24853203435598295275b61d01e**, source5+XB소유문서. latest app/data분리·alpha1UI명시동봉·publicfont notice. Python1428/1519.826s·focused22 PASS, no push. 실제alphaZIP/자동런처/native는후속이다.
- **F2 구현·검증 완료/짝 gate 대기**: recognition-only exact14 메인반영, strictRPC5/event·folder영속·busy/cancel/progress/cache integrity/rollback·preparedSynthreuse. 최종표준Python **1443/954.373s OK**, 격리29·main23·Almanac/diff/prospective-cached-diff PASS·보호4134불변. CF로그에Dart사전목록/정확SHA와 **CF gate 요청**게시. 같은소스CF GREEN전runtime커밋0, 왕복끝까지backend/contracts/tool동결. 첫불필요중단153.703s는원로그FAIL보존·lock실제변경0정정완료다.
- **M3 추가진전**: CM afd2bf94의giftkind/21lock수신·crosswalk1회재바인딩,265명1325fields/학생태그차이0·52exp동결차이0·13780grade/point차이0. Rawgift태그7차이는사유보존·ConstCommon소비0. Canonical/Schale코드메인쓰기0·독립전체제거비교null/선언CM. Darttool영향및다음반영계획을격리산출물에게시했다.
- **M5 readonly**: 현재21extract lock의고정JP/Steam2버전은already_registered로step1중단. Step2~7/key/register/import/diff/apply/gate실행0·store manifest/live lock지문불변. 설치본새버전probe/실제patch/product runner완료주장0. 근거 debug/xb_m5_lock21_dryrun_20261020/output.md.
- **보존/인계**: 기존WIP·frontend/lib/store/lock/data-extracted쓰기0·push0. F5alpha2보류·X5/X6/X7착수0. F2 debug/xb_f2_prepare_20261020/output.md; M3 debug/xb_m3_regenerate_20261020/output.md; X1 debug/xb_x1bc_f2_20261020/output.md와debug/xb_x1bc_commits_20261020/output.md. 이번F2CFgate/CF Dart연결·실게임인수는미완료이며완료라고선언하지않는다.

## 2026-10-20 23:07 — 알림(XB): M3 격리 전체 대조·제거 준비·Dart 사전 목록

- F2 ec43d230 커밋 뒤 CF f2-dart 커밋/동결 해제 회신을 기다리며 debug 격리 준비를 진행했다. Main backend/contracts/tool 추가 변경0이다.
- **M3 독립 전체 데이터 대조**: canonical 전체 차이0, 생성 STUDENTS 265명/13581필드·forms/server/favorite 선언 전부 차이0, JP stats 두 파일 exact bytes, 학생×선물13780 grade/point 차이0. 승인된 raw 선물 태그7건은 기존 사유 목록 그대로이며 무시하거나 숫자0으로 바꾸지 않았다. F2 후속 포함 격리 집중70/2.142s PASS. 첫 시험70의 editable fallback FAIL3/누락근거 ERROR1과 Windows sandbox 원자교체 FAIL은 보존했으며 전역 user-site finder를 배제한 올바른 격리/누락 입력 복사 뒤 같은 시험을 통과했다.
- **제거 후보**: Schale provider/adapter/merge-path 모듈3개·도구 함수19개/메서드7개 제거, source18 계열. 숫자 ID의 기존 DTO 이름/보존 provider_refs는 호환 데이터로 유지하되, 계산은 새 `client-character-refs.json`의 명시 local student/form→JP ID로 조회한다. 265학생/267형태 전부 기존 계산 ID와 일치한다. 새로운 provider association을 값 일치만으로 추정하지 않았고 primary는 CM 승인 crosswalk, secondary form은 명시적으로 기존 local binding 보존이다. provisional ConstCommon 소비0, exp는 승인 동결표를 사용한다. 제거 완료 선언은 CM이며 실제 main 제거/전체 gate는 아직0이다.
- **CF Dart 사전 요청(M3)**: `frontend/lib/developer_tools/legacy_tool_pages.dart` 및 실제 registry/client/Mock·시험에서 `metadata.schaledb.preview/apply/single.preview/single.apply`, `metadata.merge_paths.list/save/delete` 호출/화면을 제거할 후속 slice를 준비해 달라. 제거 뒤 해당7개 메서드는 unknown method다. 일반 metadata.list/get/save/forms/server 및 `metadata.source.view` DTO는 이번 후보에서 동일하다. `schaledb_id` 정수 필드는 기존 IPC/계산 호환 때문에 유지하되 Schale 입력/가져오기 버튼으로 쓰지 않는다. 신규 export `--from-store --bundle-output <새폴더> --crosswalk ... --frozen-gift-exp ...`는 오프라인 CLI이며 실제 GUI 신규 RPC0이다.
- **F2 후속 Dart 참고**: 오류 details={} 보장, 종료 snapshot/terminal/영속 결과가 같은 최종sequence를 사용하고 결과 저장 실패 이유도 소유권 해제 전에 고정한다. `BA_PLANNER_DISABLE_GAME_DISCOVERY=1`은 자동 Steam 탐색만 중단하며 명시 사용자 폴더는 유지한다. CF process E2E는 이 env를 사용할 수 있다. 기존 DTO 키/이벤트 모양 변화0, 새 gate 전 이 후보로 과거 gate를 확대하지 않는다.
- 근거: `debug/xb_available_work_20261020/artifacts/m3-independent-comparison.json`, `m3-removal-preparation.json`, `m3-removal-focused-v2.json/log`, `candidate/`. 최종 output은 전체 가능한 작업과 산출물 검증 후 봉인한다. CF F2 회신 후 반영 전 exact경로/SHA를 별도로 게시한다.


## 2026-10-21 00:31 — XB 검증 마감·격리 인계·남은 선행

- **이번 실제 커밋**: F2 exact14 **ec43d2305e56ac62cf65057bbc62ee28c70d3c04**, 기존 main Python1443/954.373s 및 CF gate20261020_221153 GREEN에 기반한 선택 커밋. 제품 후속은 동결 때문에 debug 후보이며 새로운 main runtime 커밋은 없다. F2 commit receipt `debug/xb_f2_commit_followups_20261020/output.md`.
- **격리 구현**: F2 후속3건(오류 details/terminal cursor·영속 순서/자동 탐색 시험 훅), M3 store read-only 재생성8산출물/Schale 모듈4·메서드7 제거 후보/명시 CharacterId267 바인딩, X3 v7 namespace·원본 보존 복사/잠금·journal 차단/시작 통합, 검증 root 경로 해석 중복 제거(모든 파일 매번 SHA 검증 유지), FD183 합성 데이터. 정확한 후속 **36경로** 패치·원/결과 SHA `artifacts/future-backend-overlay.patch/json` — 아직 main 적용0, main 보호4134 및 source338 지문 불변.
- **독립 대조**: canonical 전체/생성265명13581필드·선언5종 차이0, JP stats2 exact bytes, 제거 후 별도 인터프리터 runtime **선물13780·형태stats267·인연계산1060 전부 차이0**. 승인 raw gift tag7 변경 사유 별도 유지, exp52 동결표 사용·ConstCommon 미소비. CM 제거 완료 선언/메인 제거는 아직 없다.
- **검증**: 마지막 격리 전체 `1461/1460.226s` exit0/source drift0, **조건부 생략 2건**(새 임시 사용자 폴더에 승인 Bold 글꼴 캐시가 없어 name matcher 시험2건). 기존 공개 asset_pack의 승인 SHA f490194d9bf161f70076d01c9fb0a24d0019a324102de46c5fef579188ee96e6을 지문 확인해 fonts-only 시험 캐시로 공급한 동일 소스 name matcher **13/3.432s, skip0 PASS**로 해당2건을 별도 실행했다. 전체를 무생략 실행했다고 쓰지 않는다. 집중86 및 통합53 PASS. 원본 whole-v1 FAIL165/ERROR38/SKIP5와 누락 모듈명/시작 timeout·직렬화/도구 명령 실패를 보존, 테스트/10초 기준/golden 완화0. 향후 실제 main 전체 gate는 승인 font fixture도 포함한 격리 user dir로 실행할 것.
- **X2**: C# dual-mode 런처/build 후보 실제 컴파일, 실제 M6 ZIP 소비 포함 컴파일 harness **19 PASS/4.579s**, install staging·정확 membership/hash·호환 data·offline·flag·rollback/recovery 검증. 앱 실행·실네트워크/URL 확정·first alpha/native는 미검증. 설정 flag 경로/CF UI 연결 조건은 `prepared-handoffs.md`; `check_now`는 다음 안전한 launcher 시작 때 소비하며 현재 UI 즉시 확인이 완성된 뜻은 아니다.
- **X3 정정/경계**: 첫 startup 통합 시험에서 기존 subprocess가 user dir를 지정하지 않아 실제 기본 경로 guard에 진입했다. 해당 프로세스 종료·v7/이관마커/owned staging 부재 확인; private payload 이동/삭제는 하지 않았다. 이후 runner와 stdio subprocess는 새 임시 BA_PLANNER_USER_DIR, 실제 migration startup 시험도 합성 LOCALAPPDATA로 고정했다. 이관7 tests와 전체 검증은 합성 자료이며 실제 사용자 이관 완료 주장은 없다.
- **X4/X5/X6/X7**: 지정7학생·6changed/1new/2review·56승인+4unknown 인벤토리·비나MAX 합성 JSON/3 tests 제공, X4 실제 practice 수명/RPC/가상 replay는 **미구현**. X5 기존 진단↔privacy ROI replay 차이 감사만(새 ZIP/RPC 미구현). X6 user-run 절차·진단 수집기 **3 PASS**, 실제 native/두번째PC 측정·N/T 판정은 사용자/CM. X7 다른 캡처와 사용자 라벨 미지정으로 독립 평가/튜닝/채택0. 단계 우선순위는 M3→X2 이후 순서 유지.
- **FD183 최종(사용자 NP0035 지정 반영)**: 사용자가 2026-10-21 프라나 대상 **NP0035**를 직접 확인했다. 해당 실제 키 없는 자산은 **Spine binary4.2.33**, skel464931B SHA057e67b3832098958459cc0ae713f8eb815880009994ecb42b6f693778786fa3·atlas9721B SHAeaac5acc3206141fc0a6d1f7eceebcbb29fe0ecf97d79ac8e185ed0907109314·Texture2D2048×2048 한 장이다. Unity ClipName34개(00~20/99/Eye_Close_01/Idle_01/LookEnd_01_A/M·Look_01_M/PatEnd_01_A/M·Pat_01_A/M/Set_Front/Left/Right), bone315/slot152, Mouth_1/2/3 bone 및 Mouth_01 slot 존재 확인. 이것은 입 rig 존재 근거이며 실제 lip-sync 재생 검증은 아니다. 복잡 rig의 constraints/skin/timeline reader와 완성 정지 전신·머리 fallback은 NOT_VERIFIED, 재생 runtime/라이선스·알파1 범위 결정은 CF/CM 후속이다. 앞선 NP0090 추정은 배제/REJECTED·전 로그 정정했고 그 그림/메타데이터를 프라나로 사용하지 않는다. `plana-final-status.json`/`plana-np0035-inspection.json`이 최신 근거. 별도의 이름 Plana 3D family와 혼동하지 않는다. 키/게임 프로세스/원본 bundle·skel·mesh geometry export/Viewer·Arena/독립holdout 접근0, F2/UI 추출 runtime 확장0.
- **진행 중/차단**: 워커0. CF의 F2 f2dart 짝 커밋/동결 해제 미회신으로 main backend/contracts/tool을 계속 동결한다. CF 회신 뒤 실제36경로에서 coherent slice별 선택·경로/SHA 게시→actual main Python/Almanac/diff→M3 도구 UI 제거 및 같은소스 CF gate→선택 커밋. 후보 전체 PASS는 main/CF/native gate를 대체하지 않는다. store/ba-data.lock/data-extracted/frontend/lib·test 쓰기0, push0. 전체 P0-P6/알파/Schale 제거 완료 선언0.
