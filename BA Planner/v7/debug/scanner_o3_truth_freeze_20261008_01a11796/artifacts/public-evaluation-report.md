# W2 공개 비교 결과

PASS — 고정 공개 F8 basic 3장, 1280×720. 공개 개발 자료이며 전체 O3 승격 근거로 사용하지 않는다.

| 모드 | 정답 후보 탈락 | 최종 오답 | top-1 정답 | 미확정 |
|---|---:|---:|---:|---:|
| off | 0 | 0 | 3/3 | 2 |
| on | 0 | 0 | 3/3 | 0 |

정답 후보 탈락은 고신뢰 속성이 사용된 proposed 후보에서 정답 form이 사라지는 경우이며 fallback 전을 센다. top-1은 확정 여부 이전 pipeline 선택 form(확정된 form 또는 유효 조건부/전역 최고 후보)이다. 기존 전체 일러스트 권한/임계와 form guard를 사용하며, off는 평가기 내부 subclass로 다섯 축 판독만 비운다. on은 현재 구현 그대로다. 이름 shadow/사용자 selected 입력은 이 비교에서 사용하지 않는다.

승인 속성값은 원 검수 CSV에서 무변경 복사했고 인식 함수에 전달하지 않는다. 모든 픽셀 inference가 완료된 뒤 채점 단계에서만 CSV truth와 기존 공개 identity manifest를 읽는다. 합성은 도구 시험용으로만 남기며 실제 평가 입력에서 제외한다.

동결 UTC 2026-10-07T18:34:11.546789Z; 검수 CSV SHA a4c158abe7a23e7e0111d7969dbcaf25c70ce30921a1159f6442d889c9e9e5cc. 사람 reviewer 15개 모두 user-l01x, 값·notes 15개 보존. PNG 3개/ROI source/policy/vocabulary hashes 포함. 모델 초안과 화면 문자열·정규화값 차이 0/15. 원 capture 시각/tool/DPI의 역사적 한계는 그대로 남긴다.

실행 이력: 정상 sandbox import WinError5는 inference0. 첫 승인 실행은 off3 뒤 cleanup AttributeError로 실패(on0/metrics0/JSON0)했고 실행 중 cleanup-only 소스 변경이 있었다. 부모가 승인한 corrected 비교는 off3/on3, exit0/8.438s로 완료됐다. 실제 총 inference는 off6/on3이며 기준/후보/값 조정은 없다. 모든 이력은 attempt-history-final.json과 부모 실행 receipt/log에 보존한다.

집중 로더 1/1 PASS. 최종 candidate hash는 실행 전후와 현재 소스가 같다. 기존 필터/identity/selected 관련 보호 파일과 CSV/템플릿 불변. 전체 Python 및 커밋은 MASTER_REQUIRED이며 부모가 직렬 처리한다. holdout/evaluator-only/게임/추가 해상도·DPI/일반화는 이번 검증 범위 밖이다.
