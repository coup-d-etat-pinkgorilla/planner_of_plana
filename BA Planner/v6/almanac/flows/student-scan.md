---
title: "Student Scan Flow"
summary: "스캔 요청부터 화면 인식, 검토, 프로필 저장까지의 학생 스캔 경로와 경계를 설명합니다."
topics: [scanning, architecture]
sources:
  - id: app-flow
    type: file
    path: main.py
  - id: scanner-flow
    type: file
    path: core/scanner.py
  - id: matcher-flow
    type: file
    path: core/matcher.py
  - id: persistence-flow
    type: file
    path: core/repository.py
  - id: status-contract
    type: file
    path: docs/student_scan_status_messages.md
---

# Student Scan Flow

학생 스캔은 UI 이벤트 하나가 아니라 상태 전이, Windows 입력, 이미지 인식, 사용자
검토, 영속화가 연결된 흐름입니다.

1. `main.py`가 스캔 모드와 옵션을 확정하고 `Scanner`를 생성합니다. UI 스레드와
   스캔 작업 스레드 사이의 상태 전이도 여기서 관리합니다. [@app-flow]
2. `Scanner`가 대상 창을 이동·캡처하고 학생 카드와 상세 패널을 순회합니다.
   중단 요청, 안정 프레임 대기, 재시도는 정상 제어 흐름의 일부입니다. [@scanner-flow]
3. `core/matcher.py`가 템플릿 점수와 판독 결과를 제공합니다. 낮은 신뢰도의 값은
   확정값으로 승격하지 않고 상세 메뉴나 기존 전체 후보군으로 fallback합니다.
   [@matcher-flow]
4. 스캔 결과는 `main.py`의 검토 흐름을 거쳐 `core/repository.py`에서 기존 프로필
   데이터와 병합됩니다. UI 표시를 위해 스캔 중간 결과를 저장 형식으로 직접 쓰지
   않습니다. [@app-flow] [@persistence-flow]

상태 메시지는 단순 로그가 아니라 스캔 프로세스와 Qt 뷰어 사이의 사용자 피드백
계약입니다. 이벤트 이름이나 순서를 바꾸면 발행부와 소비부를 함께 확인합니다.
[@status-contract]

## 변경 시 확인

- 화면 이동 조건을 바꾸면 관련 stable-frame 및 timeout 테스트를 확인합니다.
- 인식 임계값을 바꾸면 빠른 경로와 fallback 경로를 모두 테스트합니다.
- 현재 상태를 낮은 신뢰도 결과로 덮어쓰지 않는 병합 규칙을 보존합니다.
- UI-only 작업이면 스캐너와 matcher를 수정하지 않습니다.

인벤토리 스캔은 같은 `Scanner`를 사용하지만 별도 그리드·스크롤 불변식이 있으므로
[Inventory Scan Flow](inventory-scan)를 따릅니다.
