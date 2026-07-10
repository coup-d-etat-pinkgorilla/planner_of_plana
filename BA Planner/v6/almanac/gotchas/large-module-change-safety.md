---
title: "Large Module Change Safety"
summary: "StudentViewerWindow, Scanner, matcher, student_meta 같은 대형 중심 모듈을 변경할 때 숨은 결합과 회귀를 줄이는 절차입니다."
topics: [refactoring, architecture]
sources:
  - id: viewer-module
    type: file
    path: gui/viewer_app_qt.py
  - id: viewer-components
    type: file
    path: gui/viewer_components/
  - id: scanner-module
    type: file
    path: core/scanner.py
  - id: scanner-components
    type: file
    path: core/scanner_components/
  - id: matcher-module
    type: file
    path: core/matcher.py
  - id: handoff-boundaries
    type: file
    path: STUDENT_PLANNER_HANDOFF.md
  - id: test-suite
    type: file
    path: tests/
---

# Large Module Change Safety

`StudentViewerWindow`와 `Scanner`의 공개 이름은 호환 façade에 남아 있고 실제 메서드는
기능 컴포넌트에 분리되어 있습니다. Qt signal, Tk callback, 스캔 상태, 프로필 저장의
숨은 연결을 놓치지 않도록 façade의 MRO와 기존 import·patch point를 함께 확인합니다.
[@viewer-module] [@viewer-components] [@scanner-module] [@scanner-components]

`core/matcher.py`도 여러 인식 전략과 fallback을 한 파일에 보관합니다. 이름이 비슷한
함수를 합치는 작업은 점수 의미, 후보 집합, 학습 캐시, legacy fallback 차이를 먼저
확인해야 합니다. [@matcher-module]

## 수정 전 절차

1. 변경할 심볼의 직접 호출자와 간접 상태 소비자를 `rg`와 정적 구조 도구로 모두
   찾습니다.
2. Qt `signal.connect`, callback 전달, 문자열 키, subprocess·상태 파일 연결은 정적
   호출 그래프 밖에 있을 수 있으므로 별도로 검색합니다.
3. 데이터 소유권과 기존 불변식을 관련 Almanac과 `docs/`에서 확인합니다.
4. 한 변경에서는 하나의 책임 경계만 추출하고, 동작 변경과 파일 이동을 섞지 않습니다.
5. 추출 전 기존 동작 테스트를 확보하고, 추출 후 동일 테스트와 관련 회귀 테스트를
   실행합니다. [@test-suite]

GUI 작업과 계산·메타데이터 작업은 병렬화할 수 있지만 동일한 대형 메서드를 여러
에이전트가 동시에 수정하지 않습니다. 비용 계산의 의미와 필터 데이터 원천 같은 기존
경계는 handoff 문서를 우선합니다. [@handoff-boundaries]

구조 분리 후 새로 생긴 모듈 경계가 장기적으로 유지되어야 할 이유가 생겼을 때만 이
Almanac을 갱신합니다. 이동된 함수 목록 자체는 코드 인덱스가 담당합니다.

프로세스 경계를 다시 확인하려면
[Runtime Boundaries](../architecture/runtime-boundaries)를 읽습니다.
