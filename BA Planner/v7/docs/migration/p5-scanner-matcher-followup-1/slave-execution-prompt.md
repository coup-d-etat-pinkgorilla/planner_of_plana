# 슬레이브 실행 프롬프트

BA Planner v7 P5 scanner/matcher follow-up-1을 수행하고 cross-PC 인계 패키지를 생성하십시오.

작업 ID:

```text
ba-planner-v7-p5-scanner-matcher-followup-1
```

먼저 다음 파일을 처음부터 끝까지 읽으십시오.

- `docs/migration/p5-scanner-matcher-followup-1/input.md`
- `docs/migration/p5-scanner-matcher/input.md`
- `docs/migration/p5-scanner-matcher/scanner-characterization.md`
- `docs/migration/p5-scanner-matcher/scanner-runtime.md`
- `almanac/workflows/p0-p6-workflow-status.md`의 P5 절
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`

이 작업은 P2나 repository persistence가 아닙니다. 마스터가 인수한 P5 contract/headless
session 부분 증분 위에서 다음 누락 범위만 완성합니다.

1. 실제 Windows capture/input adapter
2. 실제 student와 inventory matcher adapter
3. recognition asset manifest/hash/runtime resolution
4. Python JSONL response/event multiplex와 cleanup/backpressure
5. Dart typed scanner client/service와 test source

슬레이브에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없습니다. 설치하거나 공간 확보를 위해
파일을 삭제하지 마십시오. Python 검증은 직접 실행하고 Dart/Flutter/Almanac 검증은
`NOT_VERIFIED` 및 `MASTER_REQUIRED`로 인계합니다. 도구 부재만으로 `BLOCKED` 처리하지
마십시오.

변경 전 baseline gate:

- 원래 P4 commit `e0740be8951546034144a3eabd5aecea4493e459` 위에 인수된 P5 부분 증분 존재
- scanner fixture 15 cases(valid 9/invalid 6)
- P5 집중 Python 8 tests
- 전체 Python 48 tests
- 실제 adapter·asset manifest·event transport·Dart client는 아직 없음

부분 증분이 uncommitted면 정확한 10개 인수 경로만 로컬 baseline commit으로 고정해도 됩니다.
push하지 말고 commit ID를 기록하십시오. follow-up patch에 이전 59,809-byte patch 전체를
다시 포함하지 마십시오. 다른 사용자 변경이 중첩되면 `BLOCKED`로 보고하십시오.

슬레이브 필수 검증:

```powershell
cd backend
py -3.11 -m unittest tests.test_scanner_protocol_contract tests.test_scanner_session -v
py -3.11 -m unittest discover -s tests -v

cd ..
git diff --check
```

신규 production adapter, 실제 image fixture, asset hash/readiness, stdio event ordering,
backpressure와 cleanup test를 각각 단독 실행해 `verification.txt`에 기록하십시오.

마스터 전용 검증은 다음과 같이 그대로 인계하십시오.

```powershell
cd frontend
flutter analyze
flutter test
flutter build windows --release

cd ..
codealmanac validate
codealmanac health
git diff --check
```

Dart source/test를 생략하거나 skip으로 만들면 안 됩니다. student/inventory 실제 adapter,
asset manifest, JSONL event transport 또는 Dart typed client source 중 하나라도 빠지면
`COMPLETED`로 보고하지 마십시오.

결과물:

```text
docs/migration/p5-scanner-matcher-followup-1/artifacts/
├─ p5-scanner-matcher-followup-1.patch
└─ verification.txt
```

patch는 인수된 P5 부분 증분 위의 단일 증분이어야 합니다. 모든 path는
`BA Planner/v7/...`여야 하며 input, prompt, output, artifacts, 이전 patch, build/cache,
debug crop과 사용자 adaptive sample을 포함하지 마십시오. `git apply --check --verbose`에서
Checking 전체와 skipped 0을 확인하십시오.

전송:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p5-scanner-matcher-followup-1" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p5-scanner-matcher-followup-1"
```

최종 보고에는 `TASK_OUTPUT_READY`와 `CROSS_PC_HANDOFF_READY`를 포함하십시오. 마스터가 ZIP,
artifact, patch와 모든 MASTER_REQUIRED gate를 직접 확인하기 전에는 P5 완료를 주장하지
마십시오.
