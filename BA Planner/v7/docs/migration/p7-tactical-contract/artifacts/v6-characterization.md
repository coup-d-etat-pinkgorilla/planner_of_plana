# v6 tactical SQLite characterization

조사일: 2026-07-29

실제 사용자 DB는 SQLite read-only URI로만 열었고 저장소에 복사하지 않았다. 아래 내용은
개인 상대 이름과 원본 덱 행을 포함하지 않는 집계 결과다.

| 항목 | 결과 |
|---|---:|
| SQLite integrity | `ok` |
| matches | 10,475 |
| jokbo | 2 |
| source: 내 기록 | 696 |
| source: 타인 전적 | 9,180 |
| source: 스크린샷 | 599 |
| 서로 다른 학생 표시 이름 | 219 |
| exact display-name 매핑 실패 | 0 |
| exact display-name 모호성 | 0 |
| 중복 학생 슬롯이 있는 전적 | 6 |
| 공격/방어 방향을 판별할 덱이 없는 전적 | 6 |
| 비어 있는 공격/방어 방향 덱 | 20,938 |
| 잘못된 날짜 형식 | 0 |

## 의미 결정

- v6의 빈 방향 덱과 채워지지 않은 고정 슬롯은 관측하지 못한 `unknown`으로 변환한다.
- 실제 `empty`는 P7 이후 명시적 관측에서만 생성한다.
- v6 `date`는 날짜 정밀도만 가진 `occurred_at`으로 변환하며 원래 날짜 없음은 null을 유지한다.
- `created_at`은 생성 근거로, import 실행 시각은 `imported_at`으로 별도 저장한다.
- 원본 `source` 문자열은 provenance label로 보존하고 transport source는 `v6_import`로 둔다.
- 한 덱 안의 중복 canonical student ID는 원본 의미가 불명확하므로 preview issue로 반환하고
  기본 commit에서 제외한다.
- 공격·방어 양쪽 방향 덱이 모두 없거나 양쪽이 동시에 채워진 행은 방향을 추측하지 않고
  `ambiguous_direction` issue로 반환한다.
