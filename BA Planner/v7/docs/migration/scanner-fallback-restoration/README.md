# F0 — 기준선·증거·계약 고정

상태: **2026-08-30 완료**. 범위는 R01~R24의 정적 호출 경로 조사, 증거 고정,
후속 fixture 계획, 정책 결정과 오프라인 기준선 재측정이다. F1~F12는 시작하지 않았다.
스캐너 런타임·프로토콜·사용자 데이터·배포용 인식 asset은 수정하지 않았으며 게임 입력은 0회다.

## 산출물

| 파일 | 내용 |
|---|---|
| `source-manifest.json` | 현재 working tree의 v6/v7 소스 26개 SHA-256, 65개 함수의 위치·시그니처·호출·상태 의존성 |
| `dependencies-and-decisions.md` | DTO·callback·이벤트 경계, 승인된 D1/D3와 D2 승격 gate |
| `../../../backend/tests/fixtures/scanner_fallback_restoration/restoration-matrix.json` | R01~R24별 실제 호출 경로, v7 시작 상태, 담당 단계, 양성/음성 fixture 계획 |
| `../../../backend/tests/fixtures/scanner_fallback_restoration/feedback1-manifest.json` | 19개 원본 SHA·실제 크기·학생 ID/폼·부분 육안 정답과 출처 |
| `../../../backend/tests/fixtures/scanner_fallback_restoration/evidence-catalog.json` | 기존 실제 1280 자료·정답 fixture·bank 및 도구 지문, 증거 부족 목록 |
| `../../../backend/tests/fixtures/scanner_fallback_restoration/decision-contracts.json` | 승인된 목표 계약과 D2 legacy 경계값/D3 실패 시나리오; 현재 wire DTO가 아님 |
| `f0-baseline.json`, `f0-archive.json`, `f0-diagnostic-replay.json` | 이번 실행의 요약·필드별 archive 결과·224명 계산 재검증 |
| `f0-python-tests.txt`, `f0-archive.png` | 전체 Python 실행 원문과 archive 비교 이미지 |

기존 작업의 미커밋 변경은 그대로 유지했다. source manifest는 HEAD가 아니라 실제 검사한
파일 바이트를 고정한다. v6는 AST/텍스트로만 읽었으며 모듈을 import하지 않았다.
각 R의 양성/음성 항목은 **향후 실행할 fixture 계획**이다. F1~F11 tests를 이미 구현하거나
통과했다는 의미가 아니다.

## 새로 측정한 기준선

| 측정 | 결과 | 구분 |
|---|---|---|
| 전체 Python | 290/290, 95.973초 | 승인 후 재실행; 원문 첨부 |
| Archive 파일 | 313개, SHA로 정답 원본 163개 확인, 숫자 template 160개 | 기존 bank 사용, 재생성 안 함 |
| 장비 레벨 | 307/307 값, 614/614 자리 | 기존 육안 정답 |
| 인연 | 26/26 값, 52/52 자리 | 기존 육안 정답; 1/2/3자리 분리 |
| 전용무기 레벨 | 16/16 값, 32/32 자리 | 기존 육안 정답 |
| 학생 레벨 | 10/10: 1,12,23,34,45,56,67,78,89,90 | 별도 실제 프레임을 현재 기본 recognizer로 재판독 |
| 학생/무기 레벨 legacy 일치 | 각각 122/122, 89/89 | 육안 정답과 별도 집계 |
| feedback1 독립 무기 flag | 원본 19/19 + 축소본 19/19 | student-star shortcut 없이 ROI 판독 |
| 과거 JSON 재검증 | 224명: verified135 / dependency_missing75 / suspicious14 | 새 OCR 아님; JSON의 확정 상태/일괄 인연 context만 사용 |

오프라인 archive+JSON+frame 실행 시간은 52.516초다. 이는 실게임 지연·p50/p95가 아니다.
승인 전 조사에서도 Python 290개(144.642초)와 archive 재측정을 했지만, 최종 artifact에는
승인 후 재실행을 보관했다. 첫 로그 저장 명령은 잘못된 상대 경로로 테스트 시작 전에 실패했고,
올바른 경로로 다시 실행했다. 테스트 assertion 실패는 없었다.

## 증거 해석과 미검증 범위

- feedback1은 전부 실제 2560×1440 기본 화면이다. 1280×720 축소 replay는 실제 1280 캡처가 아니다.
  학생 필드 정답은 manifest에 적힌 값만 인정한다. 적히지 않은 값은 0으로 채우지 않는다.
- 전용무기 상태는 장착14/해금 후 미장착1/미해금4다. 호시노(임전) 두 폼은 `#1`/`#2`로
  분리한다. 리오(임전) 78레벨/4성 화면을 일반 리오의 정답으로 쓰지 않는다.
  일반 리오와 아리스(임전)는 feedback1에 없다.
- 기존 S3 실제 1280×720 자료는 미카 기본·공유 장비 메뉴·히비키 애용품T2를 포함한다.
  슬롯별 복사본은 별도의 독립 캡처로 세지 않는다. 원래 calibration/validation partition을 유지한다.
- S2W의 실제 상태 crop과 합성 메뉴 배선 tests를 구별한다. 합성 메뉴는 실제 상세창 정확도 증거가 아니다.
- Archive에서 장비 한 자리 9개는 지원하지 않아 제외된다. 새 독립 holdout을 만들었다고 주장하지 않는다.
- 새 실게임 입력 trace, 패널 오열림/닫기 실패, 전체 보기 off, 레벨·성급·스킬·능력개방 상세,
  재고 상세·필터·정렬·다중 페이지 이동은 해당 단계에서 확보해야 한다.
- D2의 현재 bank 음성 검증은 F7 gate다. 기존 T10 정답이 있다는 사실만으로 0.66 완화를 승인하지 않는다.

## 재현과 검증

v7/backend에서 실행한다. 원본 스크린샷은 local 외부 증거라 별도로 있어야 한다.

```powershell
py -3.11 -m tools.scanner_fallback_f0_manifest
py -3.11 -m tools.benchmark_scanner_fallback_f0 --output ../debug/f0-recheck
py -3.11 -m unittest discover -s tests -v
```

첫 명령은 F0 지문을 검사한다. 향후 F1에서 소스를 변경하면 역사적 기준선과 달라지는 것이
정상이므로 F0 manifest를 자동 갱신하지 않는다. `--write`는 명시적 snapshot 재작성 용도다.
두 번째 명령은 기존 Studio bank를 읽으며 원본 JSON·계정·template를 수정하지 않는다.
기존 archive 도구의 자동 `build()` 호출은 이 측정에서만 기존 spec 반환으로 대체한다.

문서 검증은 v7 루트의 `codealmanac validate`, `codealmanac health`, `git diff --check`로 수행한다.
프로토콜/UI 변경이 없으므로 이번 F0에서 Flutter 분석·tests·Release는 실행하지 않았다.

## 다음 단계

F1: R01/R02 캡처·입력 복구를 하나의 backend 수직 slice로 진행한다. D1/D3은 사용자 승인 완료이므로
같은 정책을 재질문하지 않는다. 먼저 캡처 방식별/중첩 시도 상한과 HWND 입력 경계를 fixture로 고정하고,
D3의 수집 후보 전달·실패 종료 계약을 연결한다. F2는 목표 패널 확인·닫기·기본 복귀를 담당한다.
새 실게임 검증 없이는 해당 단계의 live gate를 통과했다고 표시하지 않는다.
