### W2 공개 속성 truth 동결 및 공개 비교 (2026-10-08)

- 사용자 검수 15/15을 값·notes 변경 없이 별도 승인 truth v2로 동결했다. reviewer_id 15개 모두 user-l01x, CSV SHA a4c158abe7a23e7e0111d7969dbcaf25c70ce30921a1159f6442d889c9e9e5cc. 동결 UTC 2026-10-07T18:34:11.546789Z; PNG/ROI/정책 hash와 원본 동일 source-inputs 10개 포함. 모델 초안과 검수값 차이 0/15.
- 고정 공개 F8 720p 3장 수정 비교 PASS: off/on 정답 후보 탈락 0/0, 최종 오답 0/0, top-1 3/3→3/3, 미확정 2→0. CSV truth는 모든 inference 뒤 metrics에서만 사용. 합성은 도구 시험용이고 평가 입력에서 제외. 기존 selected 필터·identity·threshold 불변, 최종 candidate hash 전후 일치.
- 최초 sandbox 호출은 import WinError5(inference0); 승인 실행은 cleanup AttributeError(off3/on0/metrics0), 실행 중 cleanup-only 소스 변경 사실 포함. 부모 승인 corrected 비교 1회(off3/on3) PASS; 전체 실제 inference off6/on3. 전체 Python/커밋은 부모가 직렬 처리. 공개 3장 결과이며 O3 승격·holdout·일반화 완료 선언은 없다. 인계: debug/scanner_o3_truth_freeze_20261008_01a11796/output.md.
