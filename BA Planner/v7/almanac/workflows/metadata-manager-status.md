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
| M3 출처 전환 | main 재생성/제거·runtime 동등성 검증, CF UI/gate·source commit 대기 | 8산출물 exact bytes; gift13780/stats267/bond1060/선언5 차이0. main 전체1481 PASS(skip0); raw태그7/exp동결. 제거완료 선언CM |
| M4 자산 매핑 검증 | F2 짝 완료·후속 main 검증, UI그림/manual449 alpha2 보류 | ec43d230→f8a25bd4 동결해제. NP0035/Spine4.2.33·ClipName34·입 rig 확인, 실제 재생/정지 fallback·범위/라이선스 CF/CM 후속 |
| M5 업데이트 관리자 | 현재lock21/2pin readonly step1 중단 확인 | 두버전already_registered·store/lock불변, 설치본probe/실제patch/product runner는별도. 쓰기단계CM승인+사용자실행 |
| M6 배포 관리자 | X1 커밋, X2 C# main 반영·검증/CF gate 대기 | actual Program/updater 컴파일·영속 offline19 PASS, app/data ZIP 소비/rollback. URL·설정 UI·첫alpha/native 후속, source commit 아직0 |

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

## 2026-10-20 17:22 — XB 보고: F2 gate 대기·M3 lock21 preview

- **커밋 완료**: X1-b/X1-c **26b9df8a51b1c24853203435598295275b61d01e**, source5+XB소유문서. latest app/data분리·alpha1UI명시동봉·publicfont notice. Python1428/1519.826s·focused22 PASS, no push. 실제alphaZIP/자동런처/native는후속이다.
- **F2 구현·검증 완료/짝 gate 대기**: recognition-only exact14 메인반영, strictRPC5/event·folder영속·busy/cancel/progress/cache integrity/rollback·preparedSynthreuse. 최종표준Python **1443/954.373s OK**, 격리29·main23·Almanac/diff/prospective-cached-diff PASS·보호4134불변. CF로그에Dart사전목록/정확SHA와 **CF gate 요청**게시. 같은소스CF GREEN전runtime커밋0, 왕복끝까지backend/contracts/tool동결. 첫불필요중단153.703s는원로그FAIL보존·lock실제변경0정정완료다.
- **M3 추가진전**: CM afd2bf94의giftkind/21lock수신·crosswalk1회재바인딩,265명1325fields/학생태그차이0·52exp동결차이0·13780grade/point차이0. Rawgift태그7차이는사유보존·ConstCommon소비0. Canonical/Schale코드메인쓰기0·독립전체제거비교null/선언CM. Darttool영향및다음반영계획을격리산출물에게시했다.
- **M5 readonly**: 현재21extract lock의고정JP/Steam2버전은already_registered로step1중단. Step2~7/key/register/import/diff/apply/gate실행0·store manifest/live lock지문불변. 설치본새버전probe/실제patch/product runner완료주장0. 근거 debug/xb_m5_lock21_dryrun_20261020/output.md.
- **보존/인계**: 기존WIP·frontend/lib/store/lock/data-extracted쓰기0·push0. F5alpha2보류·X5/X6/X7착수0. F2 debug/xb_f2_prepare_20261020/output.md; M3 debug/xb_m3_regenerate_20261020/output.md; X1 debug/xb_x1bc_f2_20261020/output.md와debug/xb_x1bc_commits_20261020/output.md. 이번F2CFgate/CF Dart연결·실게임인수는미완료이며완료라고선언하지않는다.

## 2026-10-21 00:31 — XB 격리 검증 마감

- **이번 실제 커밋**: F2 exact14 **ec43d2305e56ac62cf65057bbc62ee28c70d3c04**, 기존 main Python1443/954.373s 및 CF gate20261020_221153 GREEN에 기반한 선택 커밋. 제품 후속은 동결 때문에 debug 후보이며 새로운 main runtime 커밋은 없다. F2 commit receipt `debug/xb_f2_commit_followups_20261020/output.md`.
- **격리 구현**: F2 후속3건(오류 details/terminal cursor·영속 순서/자동 탐색 시험 훅), M3 store read-only 재생성8산출물/Schale 모듈4·메서드7 제거 후보/명시 CharacterId267 바인딩, X3 v7 namespace·원본 보존 복사/잠금·journal 차단/시작 통합, 검증 root 경로 해석 중복 제거(모든 파일 매번 SHA 검증 유지), FD183 합성 데이터. 정확한 후속 **36경로** 패치·원/결과 SHA `artifacts/future-backend-overlay.patch/json` — 아직 main 적용0, main 보호4134 및 source338 지문 불변.
- **독립 대조**: canonical 전체/생성265명13581필드·선언5종 차이0, JP stats2 exact bytes, 제거 후 별도 인터프리터 runtime **선물13780·형태stats267·인연계산1060 전부 차이0**. 승인 raw gift tag7 변경 사유 별도 유지, exp52 동결표 사용·ConstCommon 미소비. CM 제거 완료 선언/메인 제거는 아직 없다.
- **검증**: 마지막 격리 전체 `1461/1460.226s` exit0/source drift0, **조건부 생략 2건**(새 임시 사용자 폴더에 승인 Bold 글꼴 캐시가 없어 name matcher 시험2건). 기존 공개 asset_pack의 승인 SHA f490194d9bf161f70076d01c9fb0a24d0019a324102de46c5fef579188ee96e6을 지문 확인해 fonts-only 시험 캐시로 공급한 동일 소스 name matcher **13/3.432s, skip0 PASS**로 해당2건을 별도 실행했다. 전체를 무생략 실행했다고 쓰지 않는다. 집중86 및 통합53 PASS. 원본 whole-v1 FAIL165/ERROR38/SKIP5와 누락 모듈명/시작 timeout·직렬화/도구 명령 실패를 보존, 테스트/10초 기준/golden 완화0. 향후 실제 main 전체 gate는 승인 font fixture도 포함한 격리 user dir로 실행할 것.
- **X2**: C# dual-mode 런처/build 후보 실제 컴파일, 실제 M6 ZIP 소비 포함 컴파일 harness **19 PASS/4.579s**, install staging·정확 membership/hash·호환 data·offline·flag·rollback/recovery 검증. 앱 실행·실네트워크/URL 확정·first alpha/native는 미검증. 설정 flag 경로/CF UI 연결 조건은 `prepared-handoffs.md`; `check_now`는 다음 안전한 launcher 시작 때 소비하며 현재 UI 즉시 확인이 완성된 뜻은 아니다.
- **X3 정정/경계**: 첫 startup 통합 시험에서 기존 subprocess가 user dir를 지정하지 않아 실제 기본 경로 guard에 진입했다. 해당 프로세스 종료·v7/이관마커/owned staging 부재 확인; private payload 이동/삭제는 하지 않았다. 이후 runner와 stdio subprocess는 새 임시 BA_PLANNER_USER_DIR, 실제 migration startup 시험도 합성 LOCALAPPDATA로 고정했다. 이관7 tests와 전체 검증은 합성 자료이며 실제 사용자 이관 완료 주장은 없다.
- **X4/X5/X6/X7**: 지정7학생·6changed/1new/2review·56승인+4unknown 인벤토리·비나MAX 합성 JSON/3 tests 제공, X4 실제 practice 수명/RPC/가상 replay는 **미구현**. X5 기존 진단↔privacy ROI replay 차이 감사만(새 ZIP/RPC 미구현). X6 user-run 절차·진단 수집기 **3 PASS**, 실제 native/두번째PC 측정·N/T 판정은 사용자/CM. X7 다른 캡처와 사용자 라벨 미지정으로 독립 평가/튜닝/채택0. 단계 우선순위는 M3→X2 이후 순서 유지.
- **FD183 최종(사용자 NP0035 지정 반영)**: 사용자가 2026-10-21 프라나 대상 **NP0035**를 직접 확인했다. 해당 실제 키 없는 자산은 **Spine binary4.2.33**, skel464931B SHA057e67b3832098958459cc0ae713f8eb815880009994ecb42b6f693778786fa3·atlas9721B SHAeaac5acc3206141fc0a6d1f7eceebcbb29fe0ecf97d79ac8e185ed0907109314·Texture2D2048×2048 한 장이다. Unity ClipName34개(00~20/99/Eye_Close_01/Idle_01/LookEnd_01_A/M·Look_01_M/PatEnd_01_A/M·Pat_01_A/M/Set_Front/Left/Right), bone315/slot152, Mouth_1/2/3 bone 및 Mouth_01 slot 존재 확인. 이것은 입 rig 존재 근거이며 실제 lip-sync 재생 검증은 아니다. 복잡 rig의 constraints/skin/timeline reader와 완성 정지 전신·머리 fallback은 NOT_VERIFIED, 재생 runtime/라이선스·알파1 범위 결정은 CF/CM 후속이다. 앞선 NP0090 추정은 배제/REJECTED·전 로그 정정했고 그 그림/메타데이터를 프라나로 사용하지 않는다. `plana-final-status.json`/`plana-np0035-inspection.json`이 최신 근거. 별도의 이름 Plana 3D family와 혼동하지 않는다. 키/게임 프로세스/원본 bundle·skel·mesh geometry export/Viewer·Arena/독립holdout 접근0, F2/UI 추출 runtime 확장0.
- **진행 중/차단**: 워커0. CF의 F2 f2dart 짝 커밋/동결 해제 미회신으로 main backend/contracts/tool을 계속 동결한다. CF 회신 뒤 실제36경로에서 coherent slice별 선택·경로/SHA 게시→actual main Python/Almanac/diff→M3 도구 UI 제거 및 같은소스 CF gate→선택 커밋. 후보 전체 PASS는 main/CF/native gate를 대체하지 않는다. store/ba-data.lock/data-extracted/frontend/lib·test 쓰기0, push0. 전체 P0-P6/알파/Schale 제거 완료 선언0.

## 2026-10-23 18:45 — XB 메인 검증 인계

- **완료(메인 반영/검증, source commit 대기)**: F2 짝 f8a25bd4 동결 해제 수신 뒤 실제 main **45경로**에 F2 details/terminal/탐색 훅, M3 offline8산출물·Schale 모듈4/도구메서드7 제거, X3 v7 namespace/원본보존 이관·시작 통합, X2 C# distribution launcher/build·영속 회귀19, 튜토리얼 content_revision2 정렬을 반영했다. exact path/SHA `debug/xb_resume_20261023/artifacts/main-source-plan.json`, review-only 선택 패치 `artifacts/source-projection-v3/selected-source.patch`. 후자는 실제 index를 바꾸지 않았고 기존 미추적 XB 진단 도구의 전체 승격을 명시했다. 기존 WIP 보존, push0.
- **검증**: 실제 main 표준 전체 **1481/934.798s exit0, skipped0, source5166 drift0**. 집중66/39.601s skip0 PASS(updater19 포함), 실제 main Program+DistributionUpdater .NET WindowsApplication 컴파일 PASS, 원10초 시작검사3/3 PASS. 승인 public Bold 글꼴 SHA fixture+임시 사용자 경로, timeout/skip/골든 완화0. 첫 whole는 EOF 공백/전역 훅 준비 정리로 중단했으며 PASS로 세지 않는다. 원로그·aborted receipt·잘못된 decoder/호스트/검토 patch 준비 실패를 모두 보존했다.
- **M3 실제 근거**: main 생성기로 고정 원래 입력을 재현해8출력 main과 exact bytes. 선물 raw tag7 승인 사유 유지·exp52 동결·ConstCommon 미소비. 동결 원본 대비 실제 main 별도 인터프리터 gift13780/stat267/bond1060/선언5 차이0. 첫 재생성 시 생성 refs를 새 입력으로 써 provenance digest만 달라졌던 출력도 보존했고, 원래 입력 digest를 검증·복원해 v2를 대조했다. 이는 소스 연관을 값 일치로 추정하거나 공식 선물식을 확정했다는 뜻이 아니다. 공용store/lock/data-extracted 쓰기0, CM 제거완료 선언0.
- **CF 응답/남은 연결**: 데이터 v2는54기본승인+기술노트26/27 검토2→56, null4; previous_inventory10(5동일/5증가), 대본3순위/예시3페이즈·네루2순위 정렬. 유우카 합성 PNG와 scanner FieldEvidence schema 검증 JSON 제공(실제 게임 캡처/역산 아님). 계약의 예시 시나리오 seed 문구 정정. runtimeImplemented=false 유지 — X4 practice 수명/복구/가상 replay 및 X5 신고 ZIP/RPC는 아직 미구현이다.
- **차단/다음**: frontend/lib/developer_tools/legacy_tool_pages.dart와 test/developer_tools_app_test.dart의 obsolete7메서드 UI/시험 정리는 CF. **무거운 Python 종료**, CF SL2/K2 후 같은소스 fe_gate GREEN→XB coherent source commit→CF paired commit 순서. 그 전 backend/contracts/tool을 고정하며 소스 커밋0(새 문서만 선택 커밋 예정). X2 실제 channel URL/설정 UI/지금 확인·첫alpha ZIP/native/두번째PC는 후속. NP0035/Spine4.2.33·ClipName34·입 rig는 기존 확정, 실제 재생/정지 fallback·라이선스/alpha범위는 CF/CM. X7 새 캡처/사용자 라벨 미수신. 전체 alpha/P0-P6/Schale 제거 완료를 선언하지 않는다.
- **인계**: `debug/xb_resume_20261023/output.md`, runtime-parity/main-regeneration-v2/main-stdio-startup/whole-v2 및 SHA manifest. main45 보호지문과 앞 봉인101파일 보존, frontend/lib·test 편집0, 실제 게임 입력·키/원본export/Viewer·Arena/독립holdout 접근0. X6 기존 사용자 실행 절차는 유지하며 수치 N/T·native 결과를 만들지 않았다.
- **전체 종료 뒤 관찰**: frontend/lib·test 대상 밖 3경로가 시작 기준과 달라졌다. main45는 계획 SHA 그대로이며, 이 프론트 변경은 수정/복원하지 않았다. post-test-external-frontend-changes.json에 별도 지문을 기록했다. 전체 실행 중 drift0과 종료 뒤 다른 레인 파일 변동을 구분하며 새 CF 같은소스 gate가 필요하다.
