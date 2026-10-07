# W2 인수 및 부모 후속 작업

1. output.md와 artifact-manifest.json의 모든 경로/크기/SHA 및 실제 새 source 3개와 artifacts/final 사본 동일성을 확인한다.
2. public-off-on-evaluation.json은 이미 부모 승인 corrected 비교 1회 결과다. 반복 실행하지 않는다. attempt-history-final.json은 실패 off3 및 실행 중 cleanup-only 수정 사실을 포함하며 실제 총 inference는 off6/on3이다.
3. MASTER_REQUIRED: 모든 W1-W5 source 동결 뒤 부모의 승인된 환경에서 전체 Python을 한 번 실행한다: backend cwd, py -3.11 -m unittest discover -s tests -v.
4. MASTER_REQUIRED: commit-files.json의 W2 실제 파일 목록만 명시적으로 stage하고, 다른 staged 파일을 섞지 않으며 부모가 커밋을 직렬 처리한다. 메시지에 a4c158abe7a23e7e 포함. 권장: Freeze public O3 attribute truth a4c158abe7a23e7e.
5. status-update-draft.md는 부모만 공용 status/P0-P6에 통합한다. 공개 소형 cohort PASS를 O3 승격/holdout/일반화 완료로 올리지 않는다.
