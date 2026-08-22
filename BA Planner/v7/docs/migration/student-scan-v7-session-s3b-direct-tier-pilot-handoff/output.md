# 작업 결과

## 작업 정보

- 작업 ID: `student-scan-v7-s3b-direct-tier-pilot`
- 상태: `COMPLETED`
- 입력 파일: `input.md`

## 수행 내용

- 하루나(체육복) T1~T10의 Shoes/Bag/Necklace 30 ROI를 template split으로 만들었다.
- 쿠루미 T2 네 화면의 동일 세 family 12 ROI를 identity-independent validation으로 분리했다.
- 기존 합성 reader, actual-ROI correlation, RGB mean-only와 prepared-feature 방식을 비교했다.
- Pilot 결과와 남은 production data gate를 Almanac에 기록했다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `artifacts/benchmark_raw.json` | 정확도·margin·성능 원자료 | 11,930 | `74a970092facad6181f2161a603cadc5b7331f6d0ecce03ba0126291d37a51eb` |
| `artifacts/fixture_manifest.json` | 42개 ROI 답지와 source provenance | 21,532 | `09ed7b77dc2984d56b62b4194d8e99d922a8179bee10f035a1d260c3154de737` |
| `artifacts/inner_icon_atlas.png` | test-only 70x40 actual inner ROI atlas | 171,304 | `b4838621f14f6cb1a548915cd433b137b13a1ceddb3a26111c4c27fbe0087b13` |
| `artifacts/MASTER_PROMPT.md` | master 재검증 명령 | 595 | `c55580956591a94b021c3a2610c2f2eae0e684d39662d3c11cddc3c0213fdace` |
| `artifacts/source_spec.json` | 입력 파일·hash·tier/split spec | 2,867 | `717c77f770cb34972a01142e0b42469694342f1a995e71659107712b4cca6406` |
| `artifacts/verification.txt` | 검증 결과와 다음 데이터 | 855 | `84fa07dd593d85b52628c8e2820b2c7a052303773476b55590880e8352b9625c` |

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| 사용자 추가 자료로 actual ROI 검증 시작 | `PASS` | exact 1280x720 14장/42 ROI fixture |
| 쿠루미를 template와 분리 | `PASS` | Haruna template, Kurumi validation |
| 합성 대비 정확도·성능 비교 | `PASS` | 합성 8/12 대 direct 12/12; prepared p50 2.233ms |
| production 안전 경계 유지 | `PASS` | runtime 미변경, 6-family/전체 validation gate 유지 |
| S4/S5 미변경 | `PASS` | 해당 범위 변경 없음 |

## 검증 내용

- 쿠루미 independent T2: direct 12/12, wrong 0, 최소 margin 0.502763.
- 기존 합성: 8/12, Necklace T2 네 건 모두 fallback.
- Prepared feature: p50/p95 2.233/2.386ms; 합성 51.928/52.810ms.
- S3B focused test 16/16, py_compile, diff check와 Almanac validate/health 통과.

## 미완료 사항 및 위험

- Hat/Hairpin/Charm/Gloves/Badge/Watch T1~T10 actual template가 없다.
- Shoes/Bag/Necklace의 독립 validation도 현재 T2만 포함한다.
- 따라서 actual ROI 방식은 pilot lead이며 production reader는 아직 변경하지 않았다.
