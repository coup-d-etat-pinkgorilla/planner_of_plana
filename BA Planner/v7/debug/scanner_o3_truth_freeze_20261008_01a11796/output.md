# 작업 결과

## 작업 정보

- 작업 ID: `scanner_o3_truth_freeze_20261008_01a11796`
- 상태: `COMPLETED` — W2 동결·공개 비교·인계 완료. 전체 Python/커밋은 부모 담당.
- 입력: `input.md`
- 승인 truth: `artifacts/approved-attribute-truth-v2.json` (v1 보존; v2는 source 사본 추가만, 값 변경 0)
- CSV SHA: `a4c158abe7a23e7e0111d7969dbcaf25c70ce30921a1159f6442d889c9e9e5cc`
- 동결 UTC: `2026-10-07T18:34:11.546789Z`
- reviewer_id: 15/15 `user-l01x`. 모델 초안과 검수값 차이 0/15.

## 공개 비교

**PASS**, 공개 F8 basic 3장/1280×720의 부모 승인 corrected 비교 1회.

| 모드 | 정답 후보 탈락 | 최종 오답 | top-1 정답 | 미확정 |
|---|---:|---:|---:|---:|
| off | 0 | 0 | 3/3 | 2 |
| on | 0 | 0 | 3/3 | 0 |

기준은 §A-⑤의 탈락0·오답0·top-1 비감소·미확정 비증가 그대로다. 승인 속성 truth는
모든 inference 뒤 metrics에서만 사용했고 인식·DB·prediction에 역주입하지 않았다.
합성은 도구 시험용으로만 표시하고 평가 입력에서 제외했다. 기존 selected 필터와
일러스트 권한/threshold/identity 구현을 보존했다. O3 승격·holdout·일반화 완료 선언은 없다.

## 실행 이력 및 검증

- focused 로더 최종 1/1 PASS(0.079s), 15행·5축·값·실제 reviewer·source integrity 검증.
- sandbox 호출은 import WinError5로 inference0. 첫 부모 승인 실행은 cleanup AttributeError로
  off3/on0/metrics0/JSON0였다. cleanup-only guard를 실행 중 변경한 사실도 보존했다.
- 부모가 승인한 corrected 비교는 off3/on3, exit0/8.438s로 완료됐다. **실제 총 inference는
  off6/on3**이다. 실패를 지우거나 단일 실행으로 표현하지 않는다. 후보·기준·라벨 조정은 없다.
- 최종 candidate freeze/실행 전/실행 후/현재 SHA 모두 일치. 보호 source·원 CSV·템플릿·README
  해시 변경 0. 원 PNG 3개와 ROI/라벨 정책 hash 및 byte 동일 source-inputs 10개 포함.
- 새 Python source 3개 syntax PASS. `git diff --no-index --check`의 whitespace 진단은 빈 출력
  (exit1은 NUL과 새 파일 내용 차이). 스테이징/커밋/전체 suite는 W2 child가 하지 않았다.

## 부모 후속 작업

MASTER_REQUIRED: 전체 source 동결 뒤 `cd backend; py -3.11 -m unittest discover -s tests -v`
한 번 실행. 기존 승인된 site-packages 환경은 부모가 적용한다.

MASTER_REQUIRED: `artifacts/commit-files.json`의 실제 W2 파일만 stage/commit한다.
커밋 메시지 예: `Freeze public O3 attribute truth a4c158abe7a23e7e`.
공용 status 수정은 `artifacts/status-update-draft.md`를 부모가 통합한다.

기존 공개 소형 cohort 한계/원 capture provenance 미확인을 보존한다.
holdout/evaluator-only·게임·Flutter·RAQM·새 해상도/DPI·일반화 검증은 수행하지 않았다.
정상 sandbox 접근 거부 뒤 W2 child는 거부 경로를 재시도/우회하지 않았고,
부모의 승인된 실행 결과를 인계한다. 자동 승인 심사 거절 사건은 없다.

## 변경 파일

- 신규 `backend/tools/student_attribute_truth.py`
- 신규 `backend/tools/evaluate_student_attribute_prefilter.py`
- 신규 `backend/tests/test_student_attribute_truth_loader.py`
- 신규 본 debug 디렉터리의 실제 파일(명시 목록 `artifacts/commit-files.json`)
- 기존 파일 수정: 없음. 원 준비 패키지를 W2 commit에 추가할 필요 없음(source-inputs 사본 포함).

## 실제 산출물

`output.md`는 아래 37개 artifacts의 존재·크기·SHA를 확인한 뒤 마지막에 썼다.
manifest는 자신의 hash 순환을 피하며 자신의 실제 hash는 아래 표에 있다.

| 경로 | 크기(B) | SHA-256 |
|---|---:|---|
| `artifacts/approved-attribute-truth-v1.json` | 22017 | `e1dbd5830107e846b624966f5e05c85d16ca895d8241fb163554ee7e98f79cac` |
| `artifacts/approved-attribute-truth-v2.json` | 23810 | `dfeaffd607d054883627c22295a557b1a785343643f5a8f16539328e10ad091a` |
| `artifacts/attempt-history-final.json` | 3135 | `23a3ccb53a11ea4257f55f6e72f1d23f3d84ec0475c39206172c80ab70ca342a` |
| `artifacts/attempt-history.json` | 2800 | `a4c58bf2a8bb6d68141e628c63d4f922211febfedb385c29b656a60f20b3771c` |
| `artifacts/bundle_truth_inputs.py` | 3445 | `c8dd8ee6bb507ba0612ccacc66e0176280847e039b2b6164a727ecbbf302e706` |
| `artifacts/commit-files.json` | 4340 | `6589df15d74c53394780cb2afb04c592b0232c9cb11468e95967ae2e27f7800b` |
| `artifacts/final/backend/tests/test_student_attribute_truth_loader.py` | 2496 | `46a59641f8a945a5ff91a23bbe7f61488f179fbf25fee687528b490b7e43df05` |
| `artifacts/final/backend/tools/evaluate_student_attribute_prefilter.py` | 10354 | `fd83dc908f1fdb2bac1497cdb405d6d155796e8a73cfa86c16f17c764033f51d` |
| `artifacts/final/backend/tools/student_attribute_truth.py` | 6990 | `522d8aced002d3e91e85d45f9f243f661b26ac83b5724f709d5d067f0a213450` |
| `artifacts/final-candidate-freeze.json` | 6622 | `2607584163c9a3166d0af26a640780a81243968f09aa6950f1f2b101d51b0817` |
| `artifacts/final-pre-evaluation-freeze.json` | 6536 | `ae1094a7d153850c70f68a989389ed5e8d645dbc3465bf99259401debdd510ef` |
| `artifacts/focused-loader-final.log` | 330 | `d89c2256a0e461f88eb6df33d5e12eb763857e5d9bc5dba5b7f297ba9e86080d` |
| `artifacts/focused-loader.log` | 330 | `9452d2fd3a1f64bb26efc0b0b5f9881017bc952484047ebcce67bd9481d05d3b` |
| `artifacts/freeze_public_truth.py` | 6847 | `7c044e2b0a215defd28e9efbd6fefc1d1801d9979e1ca3b5f2ca164f4108ca6c` |
| `artifacts/MASTER_PROMPT.md` | 1072 | `634353fffbcc4ae311cb8281bd01bd2508cd2401901913775d70a2178d5b041c` |
| `artifacts/parent-w2-attempts.json` | 739 | `1971977833a1e49a4f2ac783f373adaef329bab2ac4d3cc12d4ae39be9f8ba99` |
| `artifacts/parent-w2-public-corrected-result.json` | 948 | `7e62facd90231184c21df5f0553002df8145c8269797e41b24ed7cb21e254ac8` |
| `artifacts/parent-w2-public-corrected.log` | 224 | `37b8c9a9cb673130448e85e52c4d657a0805802ec8f7671b2f5e87d3dd02eaf8` |
| `artifacts/pre-evaluation-freeze.json` | 4675 | `1c9a624567e59d87fc73a01e34b6f84d8cad65ef086d2bcae83ac412fa8ae72c` |
| `artifacts/preservation-and-hash-verification.json` | 4423 | `aceb64f1d1be9c174580ee09605e3fc4d94ffbd404e1a5418b67796d12f9b740` |
| `artifacts/public-evaluation-report.md` | 2332 | `8fb4eef022914d4152ca8c34ec7657eb85a799e64c0726c260d06c1dab401eeb` |
| `artifacts/public-off-on-evaluation.json` | 386772 | `e1d5f87f5c566f1f929864f9b6327675bdecd6222bbfeee0d0daef068f461cf7` |
| `artifacts/seal_handoff.py` | 15588 | `168c0080421cccca6003346aae2f0f32bab4773632c25f3751681b912ab7fb09` |
| `artifacts/source-inputs/attribute-observations-model-draft.json` | 30784 | `8654eb9b1f17307a11ed3dd18a3b26a6908c410fd49b39f08192fb1967440da3` |
| `artifacts/source-inputs/attribute-vocabulary.json` | 382 | `eb2cce0bfb20cc64714c635ce32658708049731d72b9c6c03363c01efd071f29` |
| `artifacts/source-inputs/f8-manifest.json` | 2297 | `bb0486834d004e9607fc91746ce837bbb5d529c213836e081a999109a0af4818` |
| `artifacts/source-inputs/F8A001.png` | 684829 | `661e64a533a0993a9c51204381da9dc4b7a839f4ec9c57c4c34d19e59ac04cf8` |
| `artifacts/source-inputs/F8A002.png` | 710382 | `8ea3effd149a5b766b0e3d757cdaf23815e947f9c6243ec88bc98138c90a4ca6` |
| `artifacts/source-inputs/F8A003.png` | 649951 | `48ae0272bad1dfedeebfb8346c88fa3c0aecab28a57ff1199b4b2129b91b6b63` |
| `artifacts/source-inputs/human-review-2026-10-08.csv` | 4449 | `a4c158abe7a23e7e0111d7969dbcaf25c70ce30921a1159f6442d889c9e9e5cc` |
| `artifacts/source-inputs/human-review-protocol.md` | 3359 | `f9e20a7bc17fa78dd52f47d732666b343f8f9a9494521dff08e1c5c40de34e7c` |
| `artifacts/source-inputs/ratio-crop.txt` | 601 | `0b328d83c1c940cff50a559c010e28ce116954740ba0e8c457167b6fc3237ecc` |
| `artifacts/source-inputs/student_identity_regions.json` | 1339 | `d0c839d42047c474a8541825c461008f4dda9c5b3c4e358f0dcd4191055ed268` |
| `artifacts/source-verification.json` | 769 | `221960366c72527c9765388ea0a4a9a08b7845ab33ba3f5b8471f7068267d825` |
| `artifacts/status-update-draft.md` | 1215 | `183038fef534c155d2b6789e86edd7cc06b2408b81cdd04bbcbdb03a3b923227` |
| `artifacts/verification.txt` | 1631 | `9c7a8b39e38fc3147c3ba1fd008542726b3110724aab7925f7f736d2edf33795` |
| `artifacts/artifact-manifest.json` | 6642 | `9b5f41521742ea22707949a1220e46510b8653ff4be4d64bf2b0648e0f0703c9` |
