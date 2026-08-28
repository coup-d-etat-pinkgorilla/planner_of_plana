# S5 학생 스캔 검토 UI 및 통합 E2E 인계

## 상태

`IMPLEMENTED · AUTOMATED_VERIFICATION_COMPLETE · ACTUAL_CLIENT_RECOGNITION_FOLLOWUP_REQUIRED`

S4 잠정 snapshot을 계산·근거·UI에 통합했고 S5의 실제 프로세스 흐름, viewport 회귀와 Windows
release bundle을 완료했다. 첫 실제 클라이언트 검토에서 빨간 테두리는 확인되었지만 인연 랭크
인식 품질은 승인되지 않았다. UI 세부 디자인 평가는 후속 재편집까지 보류한다.

## 첫 실제 클라이언트 피드백

- 빨간 문제 상태 테두리: 확인됨
- `재검증` 발견성: 비교표·상세 증거 아래에 있던 액션 행을 상태 헤더 바로 아래로 이동함
- `재검증` 의미: 새 OCR이 아니라 `수정`에서 확인·변경한 후보값과 현재 repository dependency를
  다시 검증한다. 잘못되거나 누락된 값이 그대로면 revision만 증가하고 빨간 상태를 유지한다.
- 긴 결과 표: 넓은 화면의 590px 상세 프레임에 독립 세로 스크롤과 표시 scrollbar를 추가함
- UI 세부 디테일: 후속 재편집 예정이므로 현재 승인 판단에서 제외
- 인연 랭크 OCR: 첨부 히비키 1280x720 rank 50을 rank 10으로 읽는 문제를 재현·보정함.
  갱신 후 rank 50/confidence 1.0이며 기존 독립 검증 8건도 유지됨
- 후속 Windows build와 bundle 동기화 완료

## 보유 다른 의상 순환 대기 해소

- 이전 동작: 두 보유 의상의 랭크가 모두 미확정이면 양쪽이 서로의 확정값을 기다려 둘 다
  적용할 수 없었음
- 변경 동작: 프로필에서 다른 의상의 보유가 확인됐고 남은 dependency가 그 의상 랭크뿐이면
  녹색 `다른 의상 랭크 적용 대기` 상태와 `적용`을 제공함
- 첫 의상을 적용한 뒤 다른 의상을 스캔·적용하면 repository의 랭크가 순차적으로 채워지고
  마지막 의상에서 전체 인연 기여를 계산·검증할 수 있음
- 프로필/보유 미확정, OCR 불확실, 필수 필드 누락, 패시브 누락, 스탯 불일치와 저장소 오류는
  계속 빨간색이며 이 예외로 우회되지 않음

## 자동 검증

| 검증 | 결과 |
| --- | --- |
| Backend 전체 | PASS — 217 tests |
| Flutter 전체 | PASS — 388 tests, `--concurrency=1` |
| Flutter analyze | PASS — no issues |
| Scanner real-process E2E | PASS — edit/revision/revalidate/approve/conflict/commit/restart |
| Scan workspace viewport | PASS — 800x720, 1280x720, 1440x900, 1920x1080 |
| Windows release build | PASS |
| Release freshness | PASS — synchronized bundle is current |

기본 병렬 Flutter 실행에서는 여러 Python-process E2E가 동시에 시작되며 기존 10초 startup
제한을 넘길 수 있다. 관련 9개 process test 파일은 모두 개별 통과했고 전체 직렬 실행도
통과했으므로 인수 기준은 결정적인 `flutter test --concurrency=1` 결과로 기록한다.

## 릴리스

| 산출물 | 크기 | SHA-256 |
| --- | ---: | --- |
| `release/ba_planner_v7.exe` | 80,384 bytes | `9DD3C7080D8938E23F49EB11F047F075D2C918B0B660BEE3A28AD25659EC5B07` |
| `artifacts/MASTER_PROMPT.md` | 1,513 bytes | `459785400D63793CBCE02CB8472F89102CEC496E237D81541A2A79662E308CBB` |

Release source fingerprint:
`4BEC4530FE30EBE37A793BD6CAC676AF5C6E9DDCD815560245558CBAD0A5E9F3`

## 남은 인수 항목

- 갱신된 release에서 상태 헤더 바로 아래의 `수정`·`재검증`·`보류` 노출을 확인한다.
- 실제 클라이언트 인연 랭크 오인식별 원본 화면, 실제 rank와 판독 rank를 확보한다.
- 확보 자료로 ROI/분할/template/threshold 원인을 분리하고 회귀 fixture를 추가한다.
- 다른 의상 인연 랭크/기여와 패시브 포함 계산값이 실제 표시값과 일치하는지 확인한다.
- 좁은/일반/최대화 창에서 잘림·겹침·접근 불가가 없는지 확인한다.
- 빨강/녹색 상태 screenshot 또는 관찰 결과를 이 인계에 추가한 뒤 S4/S5를 최종 승인한다.
