# W4 작업 결과

## 작업 정보

- 작업 ID: `favor_cafe_w4_20261008_01a11796`
- 상태: `COMPLETED` — 로컬 추출·정적 판독·인계 준비 완료. 공용 import·상태 append·전체 Python·커밋은 root가 수행한다.
- 입력: `input.md`; 최신 W4/D6와 parent의 단일 쓰기 범위를 따랐다.

## 결과

- `FavorLevelExcel.json`: **100행**, 3,459 bytes, SHA-256 `3d76612c4e3b7f7f685dd45bcd38cccd0af48373d5ad6aeaf6269c967edc4293`.
- `CafeInteractionExcel.json`: **276행**, 104,975 bytes, SHA-256 `fab6c94f38a5ab0ea6ed426e1bf312adba695aa26e3469a313b69bcde1f61209`.
- 전체 필드를 object API로 보존했다. Cafe276행 보상은 모두 `FavorExp(11) / Id0 / Amount15`.
- evidence `docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json`은 두 표 전체 행, 행집합 SHA, pinned provenance, ExpType 판단, Const 후보, single-function dis와 불확정 범위를 자체 포함한다.
- ExpType: **해석 미확정 + 후보2개**(랭크별 필요 경험치 / 누적 임계값). Level1..100·long벡터길이1·초기동일값반복은 기록하되, 그룹1→원소0 변환과 랭크 경계를 확정하지 않았다. 기존 CharacterExcel7792행 분포0=7131/1=661; Cafe276ID는 모두 type1.
- 쓰다듬기 간격: JP `CafeService.get_InteractCooltime` RVA `0x1338160`의14명령·정확 unwind에서 binary64 `3.0` 로드 → `System.TimeSpan.FromHours` tailcall을 확인했다. **클라이언트 getter 기준3시간 [코드]**. 가능 횟수·서버 적용·방문/리셋 규칙은 **미확인 [?]**. 24/3으로 일일 횟수를 추론하지 않는다.
- 도구 최종 SHA-256: `12507e8c054878be8c7a051a86b5ba0edaf145af557352b3a67a35e6d40b796e`. S2 기준 SHA `e35f65f1…`로 복원됨을 확인했다. 제품 변경은 TABLES 새2개와 주석뿐이다.

## 실제 artifacts

| 경로 | bytes | SHA-256 |
|---|---:|---|
| `artifacts/build_evidence.py` | 12556 | `c6ab32bfb0d690989e547952153c1a11307606f1b6cae0ecd6e57bf98075a0d5` |
| `artifacts/CafeInteractionExcel.json` | 104975 | `fab6c94f38a5ab0ea6ed426e1bf312adba695aa26e3469a313b69bcde1f61209` |
| `artifacts/commit-files.json` | 2258 | `b619c87f8e45ac33d484ea0560195cc287416432295d627d5f109e4a7064c393` |
| `artifacts/ConstCommonExcel.candidate-fields.json` | 1291 | `bfc7885dce787639845247ce584796d109225d5ae09bd0cee15d50a93960a961` |
| `artifacts/cooltime-native-resolution.json` | 556 | `5678b465800b03279c03ed24255150c516d1a2e3122dc87520e5aa0ddb92a2da` |
| `artifacts/dis/MX.GameLogic.Service.CafeService.get_InteractCooltime.txt` | 615 | `c8ceb20c2136d473dd4f1417a262e9f1527d573ea4597bebb4946d15caff2a7e` |
| `artifacts/extract_jp.py` | 8223 | `12507e8c054878be8c7a051a86b5ba0edaf145af557352b3a67a35e6d40b796e` |
| `artifacts/extract_jp.TABLES.patch` | 342 | `e9ac571f65f336af797c4c81f9115e72a3f05f04f0be4171b1fd92c4c3dbfb9e` |
| `artifacts/extraction-verification.json` | 1301 | `ead52fbf05a5d65d005ed9205ab6bfa7a39a550fd85c1f496fc74c422499d390` |
| `artifacts/favor-cafe-tables-jp-1.73.0.json` | 212800 | `a5e6c82ae949a26c0f3cd2d11721845a57f35370bae3543db1b04c454bc8e830` |
| `artifacts/favor-structure-analysis.json` | 7977 | `b1c1a794bc252e2d993b38832d1bb5f7e557329f656791fe85a06fde66b03b34` |
| `artifacts/FavorLevelExcel.json` | 3459 | `3d76612c4e3b7f7f685dd45bcd38cccd0af48373d5ad6aeaf6269c967edc4293` |
| `artifacts/final-verification.json` | 1371 | `593b2d434b7069c8cec40e0ed2bc639bafd425b39e1c5c9f083be899e6739882` |
| `artifacts/frontend-handoff-3-lines.txt` | 600 | `14575469921400a9f682332d3fe97c78347149e47d6256eabedf70c2fc0b8126` |
| `artifacts/import-command.txt` | 297 | `b0b9ac3091822669daa4d6329eef5c7237ff69712ca6b48694dd772cf2fe45ff` |
| `artifacts/jp-cafe-symbols-for-dis.json` | 360071 | `804d87f071a0a898cf67f35518fda46a2bdc3f0fb3f32d036464b68061938f2f` |
| `artifacts/jp-static-field-inventory-v2.json` | 1140250 | `d85e0fafb536b582a674a7f37257535b0da5db9b2fba4a2fd25499d9f1c12594` |
| `artifacts/jp-static-field-inventory.json` | 147679 | `7bd00b577d76194f4eea5094d696885fdb94b91462d888bdf22268b09fb5aeb7` |
| `artifacts/local-decoder-dependencies.json` | 517 | `236e3304cf50a4b87978edb2392801def50fbf43ffb4e12de8a5c05554bde4a7` |
| `artifacts/manifest.json` | 4538 | `d091a1f219e5b999550d68a139dbb1a1bd7c1e706a56deb8074f00e810a653cd` |
| `artifacts/MASTER_PROMPT.md` | 948 | `24219454a48cbb2069797babd1c09142dad70c228d7ed10c5107547dda5e5511` |
| `artifacts/prior-json-preservation.json` | 5889 | `0b19ea74cc03b2f9d9f3b6e5345e5ec2ee123ffe5e4377498b81422113ee7c02` |
| `artifacts/report.md` | 1950 | `231f4a76ed247e2bbf88342e5f8c3ee24664afaa0401d1ad8364b0eb63a757c8` |
| `artifacts/run_favor_cafe_jp.py` | 6513 | `6ed07ce903171941aeeff292ffcfe67d1a6c1972b015ae2a6a676d51851aeaac` |
| `artifacts/scan_jp_metadata.py` | 4734 | `e2ae6bb109b668dfe1e0c941897ed1cb01250125ba59c211c40b4019af4f886b` |
| `artifacts/store-status-append.md` | 1106 | `b170e89531c9419dd515c77a5ef2a901ae4a5f40acfeaabd02c07271e4180795` |
| `artifacts/verification.txt` | 1165 | `de087c1bab12493a11b85e29918159508642cf38a05722d309a5489bc8e76507` |

artifact_count: 27. manifest 자체 해시는 위 표에 기록했고, manifest는 자기 자신을 제외한 나머지 artifact를 검증한다. 최종 제품 파일의 동일 바이트 사본은 전달용이며 commit-files.json은 제품4파일과 재현·인계 파일의 정확한 scoped 목록이다.

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| JP pinned 입력·새 Favor/Cafe 전체행 | PASS | sourceSha `a5cfbbb9…`; native DLL `e2baf70e…`, metadata `df1a47ce…`, JP zip `f9e8e721…` 일치 |
| 기존 JSON 재추출/덮어쓰기 금지 | PASS | table-only override; 기존20파일 SHA는 lock19 + 기존CCL evidence1과 일치 |
| 키/원본 복사·네트워크·게임 실행 금지 | PASS | 키는 원래 파일에서 메모리로만; 원본 복사0, 네트워크0, 게임실행0 |
| ExpType 근거와 불확정 후보2개 | PASS | `favor-structure-analysis.json`, native40,039types/159,642fields 및 property 전수 검색 |
| Const 먼저·native1함수/1라운드 | PASS | ConstCommon22후보scalar(JPzip1행); related408type symbol inventory; getter1함수/1회 |
| 실제 산출물·크기/해시 인계 | PASS | artifact27개와 manifest·동일 바이트 canonical snapshot |
| 공유 저장소 import·상태 append | NOT_VERIFIED | MASTER_REQUIRED: `artifacts/import-command.txt`, `store-status-append.md` |
| 전체 Python 녹색 | NOT_VERIFIED | MASTER_REQUIRED: root가 진행 중인 공통1회 `cd backend; py -3.11 -m unittest discover -s tests -v`; 추가suite 없음 |
| W4커밋 | NOT_VERIFIED | MASTER_REQUIRED: `artifacts/commit-files.json`; 메시지 `frontend request 2026-10-08 02:45` 포함 |

## 검증과 실행 메모

- JSON 문법, 원본 JSON↔evidence rows↔artifact copies, rowCount, tool/재현script AST, dis quota와 pinned SHA20개를 확인했다.
- `import_extract.check_claims`를 read-only로 호출해 **4claims/mismatch0**을 확인했다. import main은 실행하지 않았다.
- 의존성은 기존 backend/.venv의 plana-flatbuffers0.16.0·flatbuffers25.12.19·cryptography50.0.1·capstone5.0.9이다. 두 generated module 해시도 기록했다.
- 최초 임시 추출은 전 페이지 HMAC을 완료한 뒤 DB에 없는 ConstCommon을 조회하다 게시 전에 종료되었다. 같은 완료된 임시 평문을 이용해 새표만 게시하고 ConstCommon은 JP zip에서 읽었다. 게시 후 빈 폴더 삭제가 남은 임시 JSON 때문에 실패했지만 해당 파일이 최종 바이트와 같음을 확인해 정확한 작업 파일만 제거했다. 임시 평문/디렉터리 모두 제거됨. canonical 재추출은 하지 않았다.
- escalation은 기존 로컬 의존성 읽기와 승인된 정적 추출/1함수dis에만 사용했다. automatic review rejection은 없었다. 공유저장소·로그·status·lock·프론트·tests·goldens·git mutation은 수행하지 않았다.
- 기존 debug/il2cpp_types는 Steam 전용임을 README로 확인했으므로 JP 판단에 혼용하지 않았다. Steam/Viewer/Arena 원본 또는 프로젝트 접근 없음.

## root 후속

1. 이 output의 크기/SHA를 수신 검증한다.
2. `import-command.txt`를 그대로 실행한다. evidence 단일파일이 전체 두표를 포함하므로 import가 self-contained이다.
3. 성공한 뒤 `store-status-append.md`를 `C:\Users\brigh\ba-client-data\status\jp\jp-1.73.0-e2baf70e.md` 끝에 붙인다. 소비자 lock은 변경하지 않는다.
4. root 공통 Python 녹색을 기록하고 `commit-files.json`의 exact list/message로 W4커밋1건을 만든다.
5. 아래3줄을 frontend orchestrator log로 전달한다. ExpType·횟수 미확정은 허용된 결과이며 추가 native/추출을 시작하지 않는다.

## 프론트 인계3줄

data/extracted/jp-json/FavorLevelExcel.json 100행 sha3d76612c… + CafeInteractionExcel.json 276행 shafab6c94f…; evidence docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json (전체 행·provenance 포함).
ExpType 해석 미확정: 랭크별 필요/누적 임계값 후보2개; Level1..100, long벡터1열, FavorLevelupType 매핑·레벨 경계 미검증(합산·raw type 인덱싱 보류).
쓰다듬기 보상 FavorExp(11)/Id0/Amount15(276행 동일); JP get_InteractCooltime RVA0x1338160 → FromHours(3.0), getter3시간 [코드]; 가능 횟수·서버 검증·리셋 미확인.
