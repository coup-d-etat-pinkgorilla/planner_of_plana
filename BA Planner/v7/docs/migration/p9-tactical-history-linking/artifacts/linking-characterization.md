# P9 연결 특성화

## 자동 연결 근거

자동 연결 후보는 다음 조건을 모두 만족해야 한다.

1. 사용자가 선택한 `lobby_candidate`다.
2. candidate와 match의 `opponent_identity_id`가 같다.
3. 공개 signature인 striker 1번, special 1·2번 canonical ID가 같다.
4. 양쪽 season이 모두 알려진 경우 서로 같다.
5. match 발생 시각과 candidate 선택 시각의 차이가 6시간 이하다.
6. 조건을 만족하는 candidate가 정확히 하나다.

0개이면 `unresolved`, 2개 이상이면 `ambiguous`다. 모호한 후보는
`review_required`로 남고 자동 연결하지 않는다.

## 이력 연결 구조

```text
lobby_scan
  ├─ lobby_candidate ── opponent_identity
  │      ├─ public defense_snapshot
  │      └─ optional match link
  └─ refresh_generation (deduplication boundary)

match ── full defense_snapshot
```

공개 snapshot과 완전 snapshot을 병합하거나 한쪽으로 덮어쓰지 않는다. 두 자료는 같은
상대 identity와 candidate의 optional match link를 통해 하나의 이력으로 조회한다.

## 삭제와 재연결

- 수동 재연결은 기존 candidate link를 해제한 뒤 지정 candidate 하나에 연결한다.
- unlink는 match와 snapshot 원본을 보존한다.
- lobby scan 삭제는 그 scan에서 생성된 candidate와 공개 snapshot만 제거한다.
- 상대 alias/template 추가는 identity ID를 변경하지 않는다.
