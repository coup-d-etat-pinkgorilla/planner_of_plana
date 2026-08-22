# 작업 결과

## 작업 정보

- 작업 ID: `student-scan-v7-s3b-actual-tier-production`
- 상태: `COMPLETED`
- 입력 파일: `input.md`

## 수행 내용

- 아이리(밴드), 하루나(체육복), 칸나의 exact 1280x720 T1~T10에서 9-family 90-template
  actual inner-ROI bank를 생성했다.
- Runtime tier normal path를 시작 시 준비하는 direct `PreparedFeature` 비교로 전환했다.
- Score 0.65와 margin 0.08을 통과하지 못하거나 bank가 없으면 기존 합성 reader로 fallback한다.
- 사용자 결정에 따라 새로운 independent T1~T10 촬영은 생략하고 v6 fixed-position 검증을
  acceptance 근거로 기록했다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `artifacts/benchmark_raw.json` | 90-template production benchmark | 8,324 | `594556ba1710d4aaa4ede11695fdcbef15776708c033848d240398ff55daf0f9` |
| `artifacts/MASTER_PROMPT.md` | master 재검증 명령 | 501 | `970e95f67e06d20d1b5436fa5a8c66da3c85a2a944f970c92bf2ddbd51d09e76` |
| `artifacts/source_spec.json` | 30 source files와 SHA-256 | 4,278 | `8898b48d15cb0fecac46634fe627e4652098a42ae02644de62d68601c004d536` |
| `artifacts/tier_bank_atlas.png` | runtime 90-template actual ROI atlas | 433,772 | `d6f68361163235fa6e2811c1274c55147ac3789ab11651d30e54013cfd33ef6b` |
| `artifacts/tier_bank_metadata.json` | family/tier/atlas box/provenance | 32,552 | `96702195081c19b241aba12d617b0010898bad4e79fcc819f44506521f253487` |
| `artifacts/verification.txt` | 검증 결과 | 756 | `3b6b3b708fa37ea230ddf41f627b8ad5cf2e6f3bd4ebee52aca28343124b2d19` |

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| 추가 두 sample 반영 | `PASS` | Airi/Kanna T1~T10 exact 20장 |
| 9-family bank 완성 | `PASS` | 90/90 templates |
| independent validation 생략 | `PASS` | 사용자 결정과 v6 fixed-position 근거 metadata/Almanac 기록 |
| direct ROI production 전환 | `PASS` | `equipment_direct_icon_tier` normal path |
| 기존 안전 fallback 보존 | `PASS` | uncertainty/missing bank에서 synthesized reader 호출 |
| S4/S5 미변경 | `PASS` | 해당 범위 변경 없음 |

## 검증 내용

- Template self-check 90/90, wrong 0, 최소 margin 0.129761.
- 기존 Kurumi/Mika/Hibiki exact regression 30/30, wrong 0, direct source 30/30.
- 쿠루미 Necklace T2 score/margin 0.999931/0.144884.
- Warm p50/p95 1.960/2.269ms, bank prepare 52.269ms, cold 91.631ms.
- Focused 38/38, full backend 203/203, py_compile, diff check와 Almanac 검사 통과.

## 미완료 사항 및 위험

- Actual bank는 정책상 exact 1280x720/16:9 전용이다. 다른 해상도는 이 승격 근거에 포함하지 않는다.
- 새로운 identity-disjoint T1~T10 검증은 사용자 결정으로 생략했으며, 기존 30-ROI 독립 회귀는 유지한다.
