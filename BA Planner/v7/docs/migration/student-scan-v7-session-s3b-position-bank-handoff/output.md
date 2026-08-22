# 작업 결과

## 작업 정보

- 작업 ID: `student-scan-v7-s3b-position-bank`
- 상태: `COMPLETED`
- 입력 파일: `input.md`

## 수행 내용

- 새 다섯 화면을 분류해 exact 1280x720 네 장의 10~19/일의 자리 0~9 coverage를 승인하고,
  2560x1440 한 장은 diagnostic-only로 분리했다.
- 원본 screenshot pixel을 포함하지 않는 첫 위치 1~9/둘째 위치 0~9의 compact 19-mask bank를
  생성하고 recognition manifest 및 asset sync에 연결했다.
- 고정 위치 binary level matcher를 production-selected로 배치했다. 점수/마진, tier-level
  validity, blank와 외부 component contamination이 불확실하면 기존 fallback을 유지한다.
- test-only ROI atlas/manifest, benchmark, negative 및 production adapter 회귀를 추가했다.
- S3B workflow, P0-P6 status, session input과 exact-1280 coverage 문서를 갱신했다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `artifacts/benchmark_raw.json` | 349-pair 정확도·성능·fallback benchmark | 2,652 | `7eba88cf279fccae8cdde3549e62a62a1770a678b835ddb2f9f1fa70895bd908` |
| `artifacts/digit_fixture_manifest.json` | 신규 실화면 ROI 답지와 source hash | 8,994 | `e14e14bb989a5ac0665233a3cd309392ddbe8fd757b280052f2deaf2769a00ad` |
| `artifacts/MASTER_PROMPT.md` | master 재검증 명령과 경계 | 741 | `cc9b301914560f854871984387ac8184b3a963d0bb7c9c3e747d6c6bda46fe29` |
| `artifacts/position_digit_bank.json` | runtime과 동일한 19-mask compact bank | 5,751 | `622df595cd1baa955aee070c9d9adef2b09d3064f566a03426306098c075dbdc` |
| `artifacts/roi_atlas.png` | test-only 15-ROI atlas | 40,460 | `87d2338cfce41e196e80740216a89791f8460cc6efceef7b1413d2f7f9239888` |
| `artifacts/source_spec.json` | 다섯 입력 화면의 기대값 spec | 1,764 | `ed7810bc8e26c57b8bd07684521b2102a9984303fa4c6a9f45e7a29d69340d2f` |
| `artifacts/verification.txt` | 실행 검증과 환경 재현 메모 | 1,335 | `6d0941ccbb07bd2d3d8be59b120be235ffe916991336a0dc3d1985341c1f21cd` |

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| 추가 digit 자료가 충분한지 판정 | `PASS` | exact 네 장이 10~19, 일의 자리 0~9, slot 1~3을 충족 |
| 19-mask level 경로 구현 | `PASS` | runtime bank와 recognizer production path |
| screenshot/runtime asset 분리 | `PASS` | runtime bank source pixel 없음; atlas는 tests/handoff 전용 |
| 정확도와 fallback 감소 | `PASS` | 349/349, accepted wrong 0, exact 30/30, menu 6→0 |
| S3B까지만 변경 | `PASS` | S4/S5 코드와 상태는 변경하지 않음 |
| Almanac과 handoff 갱신 | `PASS` | `codealmanac validate`와 `health` 통과, 본 인계 완성 |

## 검증 내용

- Focused 35 tests 통과.
- Full backend 200/200 통과 후 최종 component guard를 추가하고 S3B 15/15 재통과.
- Position benchmark 349/349, accepted wrong 0, exact 1280x720 30/30.
- `py_compile`, `git diff --check`, `codealmanac validate`, `codealmanac health` 통과.
- 현재 shell의 시스템 Python에는 Pillow/jsonschema가 없고 workspace `.venv`도 없어 마지막
  full-suite 반복은 수집하지 못했다. 성공한 전체/후속 focused 결과와 재현 명령은
  `artifacts/verification.txt` 및 `artifacts/MASTER_PROMPT.md`에 보존했다.

## 미완료 사항 및 위험

- Kurumi Necklace T2는 T2가 top-1이지만 score 0.493740/margin 0.009946으로 tier-icon gate에서
  거부된다. 이는 level bank와 별개이며 full S3B end-to-end production 완료 전 해결해야 한다.
- 이번 승격은 19-mask equipment level 경로만 해당한다. S4/S5는 시작하지 않았다.
