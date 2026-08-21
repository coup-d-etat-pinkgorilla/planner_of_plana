# 작업 결과

## 작업 정보

- 작업 ID: `student-scan-v7-session-s3b-promotion-probe`
- 상태: `COMPLETED`
- 입력 파일: `input.md`
- 원본: `C:\Users\brigh\Pictures\Screenshots\BA` (read-only)
- 범위: 추가 6장 검증 및 production 승격 조건 정리. 승격 구현과 S4/S5는 제외.

## 수행 내용

- 최신 6장이 모두 exact 2560x1440이며, T1 1/8/9와 T2 12/16/18을 각각 쿠루미,
  니코, 수영복 사오리 세 학생으로 반복한 화면임을 육안 확인했다.
- 전체 archive 200장을 runtime 순서로 재분석했다. 분석 도구에 남아 있던 level 선행 조건을
  제거해 student ID → metadata family → icon tier → binary level 순서를 production과 맞췄다.
- T1 한 자리 9 ROI는 중앙 정렬된 숫자를 고정 두 cell로 나누면서 모두 잘못된 두 자리
  후보가 되었다. Candidate accuracy와 gate acceptance가 모두 0/9이므로 실제 blank coverage
  gate는 실패다.
- T2 9 ROI의 top-1 후보는 12/16/18로 9/9 맞았지만 score 0.488096-0.499431과 일부 margin
  0.019369-0.034806 때문에 gate acceptance는 0/9이다. 기존 통과 표본과 겹치므로 전역
  threshold를 낮추는 해법은 승인하지 않았다.
- 수영복 사오리 두 화면은 student/family/tier gate를 통과했지만 니코/쿠루미 네 화면은
  student matcher margin 부족으로 실패했다. 새 18 ROI 중 end-to-end eligible은 6개다.
- `binary_production_enabled=false`, generated/menu fallback과 S4/S5를 유지했다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `artifacts/promotion_probe_report.json` | 6개 source hash, 답지, 후보, gate 결과와 remaining gates | 2,668 bytes | `e2855fe2fd665cdcafad93053486283c43c43ecf55535d7487a915dd2559fbd3` |
| `artifacts/verification.txt` | 실행 결과, 검증 통과 내역과 master 후속 조건 | 1,570 bytes | `a831accca88bf6fe15345779a66b9d7744193ff5492c46a6a81c875a36a0335b` |

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| 추가 6장 확인 | `PASS` | 6 source SHA-256과 육안 답지를 report에 기록 |
| position-2 2/6/8 실제 표본 | `PASS` | 12/16/18 세 학생 반복, top-1 9/9 |
| 실제 single-digit blank 처리 | `FAIL` | T1 1/8/9 candidate 0/9 |
| current confidence gate | `FAIL` | T2도 accepted 0/9 |
| end-to-end student/family/tier gate | `FAIL` | Saori 6/6 ROI만 eligible; Niko/Kurumi 실패 |
| non-Lv70 exact 1280x720 | `NOT_VERIFIED` | 여섯 장 모두 2560x1440 |
| production promotion | `NOT_VERIFIED` | matcher 및 evidence gate 미충족 |
| S3B 회귀 | `PASS` | `tests.test_student_equipment_s3b` 10/10 |
| Almanac | `PASS` | validate/health 통과 |
| S4/S5 미변경 | `PASS` | 해당 범위 수정 없음 |

## 검증 내용

- 전체 archive 분석: 200 screenshots, 600 slot observations.
- 새 표본: T1 candidate 0/9, T2 candidate 9/9, confidence accepted 0/18.
- `python -m json.tool`: PASS.
- analyzer `py_compile`: PASS.
- S3B unit tests: 10 tests passed in 4.215s.
- `codealmanac validate`: PASS.
- `codealmanac health`: PASS, orphan/dead-ref/broken-link/source 항목 모두 0.

## 미완료 사항 및 위험

- `MASTER_REQUIRED`: foreground bounding box 또는 connected-component 기반의 center-aware
  한 자리 parser를 구현하고 실제 1/8/9를 검증한다.
- `MASTER_REQUIRED`: 12/16/18에 대해 ROI 정규화 또는 독립 template bank를 개선한다.
  현 전역 score/margin threshold를 먼저 낮추지 않는다.
- `MASTER_REQUIRED`: 니코/쿠루미 student recognition asset을 추가하고 세 학생 18 ROI를
  end-to-end로 다시 검증한다.
- `MASTER_REQUIRED`: 기존 accepted 316쌍과 새 18쌍을 독립 답지로 재생해 false positive 0을
  확인하고, fallback/menu-call 감소와 cold/warm p50/p95를 다시 측정한다.
- `MASTER_REQUIRED`: 같은 non-Lv70 구성의 exact 1280x720 반복을 확보한다.
- 모든 gate 이후 production enablement를 master가 명시적으로 승인해야 한다.
