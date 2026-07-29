# P12 규칙 기반 baseline 시간 분리 backtest

## 방법

`contracts/fixtures/tactical_recommendation_v2.json`의 관측을 시각순으로 정렬하고 각 holdout보다
엄격히 이른 snapshot만 학습 근거로 사용했다. 같은 timestamp와 같은 snapshot은 train/test에
동시에 들어가지 않는다. 각 holdout의 당시 상대·시즌·공개 signature·rank difference로 같은
6단계 규칙을 다시 실행했다.

## 기준 결과

| 지표 | 결과 |
|---|---:|
| 평가 사례 | 3 |
| TOP-1 적중 | 0.3333333333 |
| TOP-K 적중 | 0.6666666667 |
| 숨은 슬롯 적중 | 0.8333333333 |
| Brier score | 0.8381812710 |
| log loss | 11.7488228010 |
| train/test 동일 snapshot | 0 |
| calibration gate | 실패 |

이 fixture는 알고리즘 우수성을 주장하기 위한 표본이 아니라 leakage와 metric 계산을 고정하는
회귀 기준이다. production calibration gate는 평가 20건 이상, TOP-1 0.5 이상, Brier 0.5
이하를 동시에 요구한다. 현재 기준은 gate를 통과하지 않으므로 UI 기본 표현은 정밀 확률이
아니라 `low/medium/high`와 실제 근거 수다.
