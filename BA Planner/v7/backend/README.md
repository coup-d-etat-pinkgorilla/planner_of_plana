# v7 Python backend

이 디렉터리는 Flutter와 별도 프로세스로 실행될 headless Python 백엔드입니다.
현재 첫 수직 슬라이스로 계획·비용 계산과 학생 메타데이터만 포함합니다.

`core/runtime_paths.py`는 패키지에 포함된 계획 데이터와 선택적 외부 asset
override만 해석합니다. 프로필 저장 위치와 scanner template 경로는 아직 이
모듈의 책임이 아닙니다.

다음 모듈은 의도적으로 포함하지 않았습니다.

- `repository`: scanner 결과 DTO와 분리한 뒤 이전
- `scanner`, `matcher`: 캡처·입력·상태 이벤트 계약을 고정한 뒤 이전
- GUI 모델과 formatter: Flutter presentation 계층에서 재작성

