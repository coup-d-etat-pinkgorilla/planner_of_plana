# BA Planner v7

BA Planner v7은 Flutter for Windows 프론트엔드와 headless Python 백엔드를
분리해 새로 구축하는 세대입니다. v6의 Qt/QML/QWidget/Tk UI를 복사하지 않고,
검증된 도메인 로직과 데이터 계약만 수직 슬라이스 단위로 이전합니다.

## 현재 상태

- Flutter Windows 렌더러와 실제 홈 PNG hover 검증 화면
- 계획 목표 모델과 성장 비용 계산
- 학생 정적 메타데이터 lookup API
- v6 계산 결과를 고정한 Python parity fixture
- protocol v1 공통 envelope 초안

스캐너와 저장소는 아직 이전하지 않았습니다. v6 `repository`가 scanner DTO를
직접 import하고 scanner가 캡처·입력·matcher·상태 callback에 결합되어 있으므로,
DTO와 application service 경계를 먼저 분리한 뒤 옮깁니다.

## 구조

| 경로 | 책임 |
| --- | --- |
| `frontend/` | Flutter Windows UI와 UI 전용 asset |
| `backend/` | UI 프레임워크에 의존하지 않는 Python 로직 |
| `contracts/` | Flutter/Python 공용 IPC envelope와 fixture |
| `docs/migration/` | v6 지식, 복사 근거와 이전 상태 |
| `almanac/` | v7의 장기 경계와 불변식 |

## 검증

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v

cd ../frontend
flutter analyze
flutter test
flutter build windows --release
```

## v6 관계

v6는 안정판과 회귀 기준으로 남습니다. v7은 `../v6`를 런타임에서 import하지
않으며, 새 기능의 기준 구현은 v7입니다. 필요한 v6 버그 수정은 명시적으로
선별해 역이식합니다.

