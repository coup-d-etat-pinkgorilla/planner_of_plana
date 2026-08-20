# v7 학생 스캔·스탯 검증 다음 세션 handoff

## 결정과 목표

사용자는 v6 학생 스캔 기능을 v7에 실제 연결하고 후보 검토 화면까지 완성하기로 했다.
앞선 조사 결과 학생 스탯 계산도 도입하며, 스캔한 HP/ATK/DEF/HEAL을 독립적으로 검증하는
용도로 사용한다. 이 검증을 정확히 하려면 인연 랭크 스캔이 필수다. 기존 학생 장비 스캔의
고비용 생성형 템플릿 경로도 이번 이전에서 최적화한다.

장기 규칙과 단계 정의는
`almanac/workflows/student-scan-validation-workflow.md`가 소유한다. 이 문서는 다음 세션이
현재 코드 상태와 발견 사항을 다시 조사하지 않고 착수하기 위한 인계 기록이다.

## 확인된 코드 상태

### v7

- `backend/core/scanner_matchers.py`의 `StudentMatcherAdapter`는 학생 ID만 인식한다.
- 반환 payload는 `{"version": 1, "student_id": ..., "values": {}, ...}`다.
- `backend/core/repository_dto.py`에는 레벨, 인연, 성급, 무기, 장비, 전투 스탯 필드가 있다.
- `backend/assets/recognition/v1/regions/student_normal_info_regions.json`에는 대부분의 v6
  학생 기본 화면 ROI가 들어와 있으나 인연 랭크 ROI는 없다.
- `backend/core/scanner_session.py`는 candidate/review/commit, generation, sequence,
  cancellation과 review-required 경계를 이미 제공한다.
- `frontend/lib/ui/pages/scan_page.dart`는 후보를 학생 탭으로 handoff한다.
- `frontend/lib/ui/pages/student_page.dart`의 현재 검토 UI는 raw map/evidence 문자열과
  승인·보류 버튼뿐이며 필드 수정·계산 비교·차이 시각화가 없다.

### v6

- `../v6/core/scanner_components/student.py`에 레벨, 성급, 스킬, 무기, 장비, 전투 스탯
  스캔 orchestration이 있다.
- `../v6/core/matcher.py`에 숫자/아이콘 matcher와 fallback이 있다.
- 인연 랭크 스캔은 v6 어디에도 없다. 함수·ROI·템플릿을 신규로 만들어야 한다.
- 장비 fast path는 기본 화면에서 empty/locked, tier와 level을 읽고 확정 실패한 슬롯만
  장비 메뉴로 fallback한다. 한 장의 메뉴 캡처를 세 슬롯이 공유한다.
- 장비 생성형 level matcher는 각 가능한 레벨마다 2560x1440 RGB 참조 canvas를 만든다.
  T10 한 cache miss만 최대 약 738 MiB의 일시 픽셀 할당을 유발할 수 있다. 이 경로는
  v7로 복사하지 않는다.

## 외부 계산 기준

- Schale 학생 기본 스탯은 Lv1/Lv100 선형 보간과 정확한 중간 반올림을 사용한다.
- 성급은 HP/ATK/HEAL에 누적 배율을 적용하고 DEF에는 적용하지 않는다.
- 장비 중간 레벨은 `(level-1)/(maxLevel-1)`을 소수점 네 자리로 만들고 StatValue 시작·최대
  사이를 보간한 뒤 반올림/ceil한다.
- 인연은 `FavorStatType`, `FavorStatValue`, `FavorAlts`가 필요하다.
- 구간은 2~5, 6~10, 11~15, 16~20, 21~30, 31~40, 41~50이며 51 이상은 증가하지 않는다.
- 다른 의상의 인연 스탯도 각 의상 랭크에 따라 합산된다.

## 아직 fixture로 확정해야 하는 것

1. 인연 랭크가 표시되는 실제 학생 화면과 ROI
2. 랭크 1/9/10/20/50/100 및 두 자리·세 자리 숫자 glyph
3. 2560x1440 이외 해상도에서 perspective/ratio 안정성
4. 게임 기본 화면 HP/ATK/DEF/HEAL에 패시브 스킬이 포함되는지
5. 다중 폼 전환 시 인연 표시와 전투 스탯의 관계

실제 캡처가 없으면 값을 추측해 region을 확정하지 않는다. S4는 fixture 확보 전 해당 부분을
`BLOCKED`가 아니라 명시적인 acquisition gate로 보고하고, 나머지 순수 로직까지만 진행할 수 있다.

## 세션 순서와 소유 파일

| 세션 | 범위 | 주 소유 경로 | 선행 조건 |
|---|---|---|---|
| S1 | Schale 정적 DTO와 순수 스탯 계산 | `backend/core/`, sync tool, Python tests | 현재 baseline |
| S2 | v6 학생 기본 인식의 v7 headless 이전 | scanner/matcher Python, recognition regions/tests | S1 accepted |
| S3 | 장비·애용품 fast path와 성능 최적화 | 장비 matcher 모듈/assets/tests | S2 accepted |
| S4 | 인연 OCR, alt dependency, 계산 evidence | scanner validation/contract/tests | S3 accepted + capture fixture |
| S5 | Flutter 검토 workspace와 통합 E2E | scanner Dart model, student/scan UI/tests | S4 accepted |

각 세션은 하나의 수직 슬라이스만 수행한다. 다음 세션 범위를 미리 구현하지 않는다. 특히 S2~S4를
병렬로 실행해 같은 scanner 파일을 동시에 수정하지 않는다.

## 공통 구현 제약

- `../v6`를 런타임 import하지 않는다.
- Qt/QML/QWidget/Tk/PySide 코드를 복사하지 않는다.
- Python scanner와 Flutter UI는 versioned local protocol로만 연결한다.
- candidate와 repository commit을 합치지 않는다.
- 낮은 confidence와 계산 mismatch는 자동 저장하지 않는다.
- 계산 결과는 repository 현재 상태가 아니라 evidence다.
- `backend/core/student_meta_data.py`는 생성 데이터이므로 광범위하게 손수 수정하지 않는다.
- dirty worktree의 기존 변경은 사용자 소유다. 관련 없는 파일을 복원하거나 정리하지 않는다.

## 세션별 완료 gate

### S1

- 순수 함수만으로 level/star/equipment/weapon/bond/gear/potential 계산 가능
- Schale 예제 parity와 반올림 edge fixture
- 다른 의상 인연 누락을 값 0과 구별
- 저장 증가량을 compact DTO 기준으로 확인

### S2

- student matcher가 ID 외 관측 필드를 candidate values/evidence로 반환
- cancel/progress/stale session 동작 보존
- 기본 screenshot을 중복 캡처하지 않음
- v6 fixture 또는 동등한 고정 image fixture로 parity

### S3

- empty/locked → tier → level → menu fallback 순서
- unresolved 슬롯만 fallback
- 후보별 full-HD/QHD 합성 canvas 생성 금지 회귀 테스트
- 과거 v6 cold 0.9~1.05초·warm 52ms를 accepted fixture에서 먼저 재현
- RGB 후보의 gray/edge 반복 계산을 포함한 cold/warm profiler와 p50/p95 기록
- 생성 RGB, prepared feature bundle, 실캡처 glyph, 실캡처+소형 합성 fallback 비교
- 정확/오판독/fallback률, 슬롯·티어·숫자 confusion matrix, RAM과 설치 증가량 기록
- 원본 전체 화면+metadata 데이터셋을 runtime asset과 분리하고 versioned ROI로 재생성
- 저장 형식과 fallback 제거 여부는 실캡처 답지 근거 전에는 확정하지 않음

### S4

- 인연 rank OCR evidence
- alternate outfit dependency missing/complete fixture
- calculated vs observed four-stat evidence
- mismatch가 review-required를 강제하고 payload를 자동 수정하지 않음

### S5

- portrait와 current/scanned/calculated/delta 표시
- 필드 수정 후 candidate revision과 재검증
- approve/hold/reject/commit/stale conflict
- 좁은/일반/최대 viewport, full Flutter tests, analyze, process E2E와 release

## 슬레이브/다른 PC에 전달할 때

작업 프롬프트는 `almanac/workflows/slave-artifact-handoff.md`를 포함한다. 작업 디렉터리에
`input.md`, 마지막에 작성한 `output.md`, 실제 결과를 담은 `artifacts/`가 있어야 한다.
`output.md`에는 각 artifact의 크기와 SHA-256, 요구사항 PASS/FAIL/NOT_VERIFIED와 정확한
검증 명령을 기록한다. Flutter SDK가 없는 슬레이브는 source/test를 작성할 수 있으나 Flutter
test/analyze/build 통과를 주장하지 않고 `MASTER_REQUIRED`로 남긴다.

## 다음 행동

S1 입력은 `docs/migration/student-scan-v7-session-s1-input.md`를 사용한다. S1 결과를 master가
검증하고 accepted snapshot을 고정한 뒤에만 S2 입력으로 진행한다.
