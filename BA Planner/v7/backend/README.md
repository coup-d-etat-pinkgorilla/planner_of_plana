# v7 Python backend

이 디렉터리는 Flutter와 별도 프로세스로 실행될 headless Python 백엔드입니다.
현재 첫 수직 슬라이스로 계획·비용 계산과 학생 메타데이터, planning protocol v1
JSON Lines process를 포함합니다.

## process 실행

working directory를 이 디렉터리로 두고 실행합니다.

```powershell
py -3.11 -m core.backend_process
```

stdin과 stdout은 한 줄당 하나의 JSON protocol message만 사용합니다. 진단과
traceback은 stderr에 기록합니다. malformed JSON 또는 신뢰할 수 없는 envelope는
응답하지 않고 다음 입력을 계속 처리하며, EOF에서 정상 종료합니다.

editable install 후에는 동일 entrypoint인 `ba-planner-backend`도 사용할 수 있습니다.

## 검증

```powershell
py -3.11 -m pip install -e ".[test]"
py -3.11 -m unittest discover -s tests -v
```

`core/runtime_paths.py`는 패키지에 포함된 계획 데이터와 선택적 외부 asset
override만 해석합니다. 프로필 저장 위치와 scanner template 경로는 아직 이
모듈의 책임이 아닙니다.

다음 모듈은 의도적으로 포함하지 않았습니다.

- `repository`: scanner 결과 DTO와 분리한 뒤 이전
- `scanner`, `matcher`: 캡처·입력·상태 이벤트 계약을 고정한 뒤 이전
- GUI 모델과 formatter: Flutter presentation 계층에서 재작성
