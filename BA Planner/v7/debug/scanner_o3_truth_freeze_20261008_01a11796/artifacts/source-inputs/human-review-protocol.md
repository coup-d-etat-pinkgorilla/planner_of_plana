# 공개 F8 속성 라벨 검수 절차

이 패키지는 **모델 시각 판독 초안**이다. 독립 사람 검수 완료는 0/15이며,
`approved_truth_value`는 모두 null이다. 검수 전에는 이 자료를 승인 truth 또는
검출 입력으로 전달하지 않는다. 모델은 전체 원본의 이름과 공개 manifest의 identity
문자열을 보았으나 학생 DB 속성과 분류기 예측을 조회하지 않았다. 완전한 모델 맹검은
주장하지 않는다.

1. `review.html`을 로컬 브라우저로 연다. 기본 화면은 속성 ROI만 표시한다.
   모델 초안과 전체 원본은 접힌 상태다. 먼저 ROI만 읽고 별도 복사본의
   `human-review-template.csv`에 화면 문자열을 직접 적는다.
2. 공격/방어 타입의 한글 문자열, role의 한글 역할 이름, position의 FRONT/MIDDLE/BACK,
   combat_class의 STRIKER/SPECIAL을 각각 독립적으로 판독한다. role과 combat_class를
   대체 관계로 취급하지 않는다. 학생 이름·의상·portrait·DB·classifier score는 정답 근거가 아니다.
3. 문자가 실제로 읽히면 `visibility_human=observed_readable`와 문자열/정규화 값을 기록한다.
   문자열이 없으면 `unobserved`, 잘림·가림·판독 불가면 `unknown`으로 기록하고 값 칸을 비운다.
   학생 identity에서 값을 역으로 채우지 않는다.
4. 정규화는 화면 문자열에만 적용한다. 현재 초안에 등장한 매핑은
   관통→piercing, 신비→mystic, 경장갑→light, 중장갑→heavy,
   딜러→dealer, 탱커→tanker, FRONT→front, STRIKER→striker다.
   전체 허용 enum은 `source-contracts/attribute-vocabulary.json`이다.
   해당 파일에는 학생별 속성/identity 정보가 없다.
5. 판독 후에만 모델 초안을 펼쳐 차이를 기록한다. 문맥이 필요하면 전체 원본을 열되,
   `notes`에 맹검 해제와 이유를 남긴다. 양쪽 의견이 다르면 픽셀을 다시 검토하고,
   확정할 수 없으면 unknown을 유지한다. DB나 인식기 출력을 tie-breaker로 쓰지 않는다.
6. 사람이 실제로 판독한 행만 reviewer ID, UTC 검수 시각, `review_status=reviewed`를 적는다.
   모델이 사람 reviewer를 생성하거나 대리 서명하지 않는다. 이 HTML에는 저장·자동 승인 기능이 없다.
7. 검수 결과는 원 패키지를 덮어쓰지 않고 새 버전으로 저장한다. 검수 CSV, 원본 PNG hash,
   ROI source hash, 라벨 정책 버전, 변경 내역과 승인 provenance를 함께 고정한 뒤
   부모가 평가 입력으로 연결할지 결정한다. 모델 초안과 검수 완료 truth는 구분한다.

현재 픽셀 근거는 공개 fixture의 원본과 바이트 동일한 PNG 3개다.
HTML은 1280×720 원본을 (-x1,-y1)로 이동하고 사각형으로 clip한 후 3배
pixelated 표시한다. PNG raster crop을 새로 생성하지 않았다. SVG/AI 합성 이미지나
보간 결과를 정답 근거로 사용하지 않았다. 브라우저 렌더는 아직 실제 실행 검증하지 않았다.

이 준비에는 분류기 accuracy, 후보 recall, 확신 오답, 승격 수치 기준이 없다.
새 수치 합격 기준은 사용자 결정 대기다. 사람이 15개를 검수하더라도 기존 세 장으로
전체 O3 또는 일반화 통과를 주장할 수 없다.
