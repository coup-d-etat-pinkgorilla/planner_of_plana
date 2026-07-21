# Repository application service / protocol draft

이 문서는 P4/P5 설계 입력이며 P3에서 wire schema, dispatcher, Dart client를 변경하지 않는다. 기존 planning protocol v1과 호환되는 별도 repository service version 1을 가정한다.

## 제안 method

- P4: `repository.profile.create/list/select/rename.preview`, `repository.students.get/update.preview`, `repository.inventory.get/update.preview`, `repository.goals.load/save.preview`
- P5: `scanner.session.start/cancel`, `scanner.candidate.list/get/review`, `repository.candidate.commit`

모든 mutation request는 request ID와 idempotency key를 갖고, preview는 쓰지 않으며 commit만 atomic transaction을 연다. response는 `version`, payload 또는 `{code, message, details, retryable}` 구조의 error를 반환한다. unknown version/field, 누락 필수 field, 잘못된 type은 명시 오류다.

student commit의 `replace`는 해당 학생 current record 전체를 검토된 `ConfirmedStudent` 값으로 교체한다. 따라서 student commit의 `profile_ids`는 항상 비어 있어야 한다. inventory commit은 전역 `replace`를 허용하지 않고 `profile_ids`로 실제 scan이 확인된 profile 교체 범위만 지정한다. target kind와 confirmed DTO가 일치하지 않으면 dispatcher 이전 DTO 경계에서 거부한다.

## 경계 규칙

scanner candidate는 session/candidate 생명주기, target kind, payload, field evidence와 `review_required`만 가진다. low-confidence 또는 review-required candidate는 자동 commit하지 않는다. commit command는 검토된 payload를 별도로 전달하며 candidate ID를 audit reference로만 사용한다. confirmed current에는 confidence를 현재값처럼 저장하지 않고 provenance metadata로 제한한다.

정적 metadata, confirmed current, user goal, calculated total cost, inventory-derived shortage는 서로 다른 bucket이다. 빈 goal을 current 숫자 0으로 정규화하지 않는다. total need나 부족량을 inventory quantity로 쓰지 않는다. P4 repository는 current/goal persistence와 profile transaction을 소유하고, P5는 scan session/event/candidate 생성과 검토 흐름을 소유한다. P5는 P4 commit boundary를 호출하지만 storage를 직접 열지 않는다.

## P4/P5 후속 결정

P4는 JSON/SQLite source 선택, fallback error 노출, migration과 resync 정책, optimistic revision, profile rename 충돌 및 atomicity를 확정해야 한다. P5는 event ordering, cancellation, duplicate candidate, evidence vocabulary와 재시도 정책을 확정해야 한다. 삭제/교체 preview에는 affected keys를 포함하고 명시 승인 없이는 실행하지 않는다.
