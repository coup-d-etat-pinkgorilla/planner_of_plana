# 계획 요소 제작 화면 제품 계약

## 범위

첫 vertical slice는 학생 탭에서 전달된 `PlanningStudentSeed`를 한 번만 소비해
인메모리 계획 요소 제작 화면을 연다. 프리셋 영속화와 계획 탭에서 직접 학생을
고르는 흐름은 후속 범위다.

## 화면 구조

- Section 3: 선택 학생의 정적 정보와 현재 육성 상태를 읽기 전용으로 표시한다.
- Section 5: 외부에서 받은 프리셋 목록을 표시하고 선택한 프리셋으로 제작 draft
  전체를 덮어쓴다.
- Section 6: `section-preset-element.ba-section-studio.json`의 카드 문법을 사용해
  순서가 있는 누적 목표 단계들을 편집한다.
- Section 7: 아직 페이즈에 배정되지 않은 계획 요소만 표시한다. 배정된 요소는
  페이즈 편집기에서만 표시한다.

### Section 3 내부 구성

Section 3은 `section-plan-starter.ba-section-studio.json`의 내부 컨테이너 좌표와
형상을 그대로 투영하고 학생 탭의 상태 인디케이터 표현을 재사용한다.

- Container 1: 사용하지 않는다. 학생 초상은 Section 3 내부 독립 slot에서 직접 그린다.
- Container 2 / Feature 2: 학생 레벨만 표시한다. 소속 학원 영역·구분선·로고, 학생 이름과
  인연 비용 미연결 문구는 표시하지 않는다.
- Container 2 / Feature 5: 전용무기 레벨
- Container 3: 학생·전용무기 성작 게이지. 학생 탭과 동일하게 별도의 container 채움이나
  외곽선 없이 아홉 개 세그먼트만 표시한다.
- Container 5: 스킬
- Container 6: 장비와 애장품
- Container 7: 추가 능력치
- Container 8: 인연 랭크 인디케이터. 초상보다 앞에 표시한다.
- Container 9: 잠긴 심상개화

Container 10은 잘못된 Studio 데이터이므로 사용하지 않는다. 미보유 상태는 초상 이미지
위쪽의 `UNOWNED` 배지와 어두운 overlay로 표시하며 학생 탭의 카드 path·합성 계약을 공유한다.
Section 3의 Studio 폭은 상단 Container 8·1·2의 실제 사선 끝과 외곽 사이에 약
12–16px 여백이 남는 27칸이다. Container 8은 180도 반전된 학생 탭 인연 패널에 맞는
좌측 face 삼각형이며 초상 왼쪽 빗면과 약 10–12px 간격을 유지한다. Container 3·5·6·7·9는
기존 세로 위치·높이·간격을 유지하면서 우측 끝이 새 Section 3의 80도 rail에서 12px
안쪽에 오도록 가로 폭만 조정한다.

초상은 더 이상 Container 1을 사용하지 않는다. Section 3 내부의 독립 배치 slot에서 학생
탭과 같은 `AssetImageGrid`와 `StudentGridCardOverlayPainter`를 직접 사용한다. `252×204`
source를 `BoxFit.contain`으로 맞춘 카드 경로, 인연 배경 `0.11` edge crop, 초상 `0.98`
scale, `0.12` clip radius와 `0.04` alpha cutoff를 적용한다. 흰 외곽선과 `UNOWNED / PLAN /
JP` 배지도 학생 탭과 같은 fitted card path를 공유한다. `UNOWNED`는 seed의 보유 상태,
`PLAN`은 해당 학생의 기존 계획 요소 존재 여부, `JP`는 `jp_only` 메타데이터에 연결한다.
Container 1은 Studio JSON과 typed projection에서도 제거한다.

Container 8은 학생 탭의 최종 인연 인디케이터를 180도 돌린 형태다.
숫자는 다시 정방향으로 보정해 위쪽에 두고, 어두운 track과 핑크 gauge는 아래쪽에 둔다.
재구성한 이상 경로가 아니라 Container 8의 실제 rounded local path를 직접 입력받는다.
초상 slot은 Container 2의 실제 clipped path 높이에서 반응형으로 계산한다. 따라서 학생
카드의 `252:204` 비율을 유지하면서 상·하단 높이가 Container 2와 정확히 일치한다.
Container 2의 우측 rail은 고정한다. 후속 확장에서는 남은 공간의 절반을 사용하도록 좌측
경계를 12px 왼쪽으로 옮겨, 기준 2560×1392에서 초상과 Container 2의 평행 사선 간격을
24px에서 12px로 줄인다. Container 8의 placement 높이는 직전 값의 1.3배이고,
rounded triangle의 실제 visible 높이는 약 186px에서 256px로 증가한다.
후속 위치 조정에서는 이 크기를 유지한 채 Container 8의 왼쪽 수직 변을 스킬 패널인
Container 5의 좌측 시작점에 맞춘다. Container 8은 학생 탭 Container 10과 같은 texture
foundation·outline을 사용하고, clip 내부에는 `StudentBondStatus`만 직접 둔다. 계획 탭
전용 `ColoredBox`와 별도 border painter를 중첩하지 않는다. 방향 차이는 공용
`StudentBondStatus(inverted: true)`로 처리한다. 이때 이미 좌향인 실제 외곽 path를 다시
회전하지 않는다. 숫자 영역은 path 상단의 수평 span에서, 게이지는 그 아래 남은 path에서
직접 계산하며 진행량은 위에서 아래로 채운다.

공용 `StudentLevelStatus`는 학생 탭에서 레벨/학교 문양과 80도 구분선을 유지한다. 계획
Feature 2에서는 `showSchool: false` 변형을 사용해 학교 영역·구분선·로고를 렌더링하지 않고,
같은 Feature 2 외곽 크기 전체를 레벨 영역으로 사용한다. Container 2와 Feature 2의 Studio
geometry는 바꾸지 않는다.

Section 3·5·6·7 외곽은 삼각형 무늬 없이 동일한 반투명 단색 foundation을 사용한다.
Section 3 내부 컨테이너의 Studio triangle texture 설정은 그대로 보존한다.

## 단계 카드

하나의 카드는 학생 한 명의 한 단계에 대한 누적 목표 snapshot이다.

카드 외곽 캔버스는 Studio 문서의 전체 사각 범위 `(19, 9, 24, 43)`을
정규화해 사용한다. `element-5`는 `(22×43)` 배경 카드일 뿐 전체 clip이 아니며,
우측으로 더 나가는 `element-2`, `element-3`, `element-4`를 포함한 아홉 개
element의 합집합이 카드 선택·hover·ink 영역이다. 각 element는 저장된 Studio
`shape spec`을 공용 path builder에 전달해 선언 rect 안에 맞는 반응형 80도 path를
만들고, 그 실제 path 하나를 채움, 테두리, clip과 geometry test에 공통 사용한다.

- Element 1: 학생 레벨
- Element 2: 전용무기 레벨
- Element 3: 인연 랭크와 메타데이터 미연결 표시
- Element 4: 클릭 가능한 학생 5칸·전용무기 4칸 성작 스트립
- Element 5: 전체 배경과 좌측 단계 번호
- Element 6: 네 종류 스킬 레벨
- Element 7: 장비 티어·레벨과 애장품
- Element 8: HP·공격력·치유력 추가 능력치
- Element 9: 잠긴 심상개화

단계명은 카드에 중복 표시하지 않고 Section 7에서만 편집한다. 카드 선택 상태는
아홉 surface 전체의 tint와 합집합 외곽선으로 표시한다.
얇은 Element 4의 시각 높이는 Studio 값을 보존하되 입력 hit 영역은 최소 28px로
확장한다. 감소·증가 버튼도 아이콘 크기와 별개로 최소 `18×22px` 입력 면적을 갖는다.
Element 4는 학생 탭의 Container 3과 같은 공용 80도 세그먼트 렌더러를 사용한다.
각 단계의 시작 상태는 채움으로 유지하고 해당 단계의 계획 목표는 학생 성작은 금색,
전용무기 성작은 청색 테두리로 표시한다. 시각 렌더러를 통일해도 아홉 칸의 독립 클릭
hit target과 목표값 토글 동작은 유지한다.

- 학생 레벨
- 전용무기 레벨
- 인연 랭크
- 학생 성급과 전용무기 성급
- EX·기본·강화·서브 스킬
- 장비 1~3 티어/레벨과 애장품
- HP·공격력·치유력 추가 능력치
- 심상개화 잠금 표시

새 단계는 선택 단계 바로 뒤에 선택 단계의 snapshot을 복제해 추가한다. 선택이
없으면 마지막에 추가하며 첫 단계는 현재 상태에서 시작한다. 중간 단계를 삭제해도
나머지 단계 ID와 값은 유지하고 표시 순서만 다시 계산한다. 단계 순서를 직접 바꾸는
기능은 제공하지 않는다.

상위 단계 값을 올려 이후 단계보다 커지면 이후 단계의 같은 필드를 같은 값까지
자동으로 올린다. 상위 단계 값을 낮출 때는 이후 단계 값을 낮추지 않는다. 자동
변경된 필드는 UI에서 일시 강조한다.

완전히 달성된 프리셋 단계는 결과에서 제외한다. 일부만 달성한 단계는 현재 상태보다
높은 목표만 유효한 증가로 취급한다.

## 페이즈와 완결성

- 같은 학생의 여러 단계는 `(페이즈 순서, 페이즈 내부 순서)` 전체에서 단계 순서를
  지켜야 한다.
- 같은 페이즈 안에 여러 연속 단계를 둘 수 있다.
- 잘못된 순서의 drop은 자동 재배치하지 않고 거부한다.
- 미배정 요소가 있으면 페이즈 편집기 완료를 잠근다.
- 목표값, 단계 추가·삭제가 바뀌면 그 학생의 모든 단계를 미배정으로 되돌린다.
- 표시 이름만 바뀌면 기존 페이즈 배정을 유지한다.

## 미보유 학생과 미구현 계산

미보유 학생은 `미보유 가상 시작점`으로 계획할 수 있다. 레벨 1, 정적 메타데이터의
초기 성급, 잠긴 전용무기, 스킬 1, 게임상 초기 장비 상태, 애장품 없음, 추가
능력치 0을 사용하며 실제 스캔 현재 상태와 섞지 않는다.

애장품 인디케이터는 `has_favorite_item_kr`을 우선하고, 없으면 `has_favorite_item`
메타데이터를 확인한다. 메타데이터가 없거나 `no`이면 잠금 아이콘 대신 `-`를 표시한다.
메타데이터가 `yes`이면서 현재 티어가 0일 때만 잠금 아이콘을 표시하고, 해금된 경우에는
`T1` 또는 `T2`를 표시한다. 현재 catalog DTO가 이 필드를 아직 전달하지 않으므로 실제
연결은 학생 메타데이터 편집기와 catalog 계약 갱신 뒤 활성화한다.

인연 랭크는 현재값, 단계별 목표, 순서 검증과 계획 요소에는 포함한다. 필요 아이템
메타데이터가 연결되기 전까지 비용은 0으로 간주하지 않고 `메타데이터 미연결`로
표시한다. 심상개화는 잠금 상태로만 표시한다.

## 프리셋

프리셋은 절대 목표 snapshot의 순서 있는 묶음이다. 첫 단계의 미지정 필드는 학생
현재값을 유지하고 이후 단계의 미지정 필드는 직전 단계 값을 승계한다. 프리셋을
고르면 현재 제작 draft 전체를 덮어쓰며, 이후 사용자가 단계와 값을 수정할 수 있다.

이번 범위는 외부 프리셋 목록과 인메모리 fixture를 소비하는 것까지만 포함한다.
프리셋 저장·삭제·이름 변경과 repository/protocol schema는 다른 섹션에서 구현한다.
