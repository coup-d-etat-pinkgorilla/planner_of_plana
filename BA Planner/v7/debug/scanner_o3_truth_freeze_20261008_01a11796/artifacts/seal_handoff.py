"""Materialize all payloads, verify hashes, and write output.md last."""

import hashlib
import json
from pathlib import Path
import shutil


ARTIFACTS = Path(__file__).resolve().parent
TASK = ARTIFACTS.parent
ROOT = TASK.parents[1]
OWNED_SOURCE = ["backend/tools/student_attribute_truth.py",
                "backend/tools/evaluate_student_attribute_prefilter.py",
                "backend/tests/test_student_attribute_truth_loader.py"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_new(path, text):
    if path.exists():
        raise FileExistsError(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_json(path, data):
    write_new(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main():
    evaluation = json.loads((ARTIFACTS / "public-off-on-evaluation.json").read_bytes())
    truth = json.loads((ARTIFACTS / "approved-attribute-truth-v2.json").read_bytes())
    final = json.loads((ARTIFACTS / "final-candidate-freeze.json").read_bytes())
    expected = {row["path"]: row["sha256"] for row in final["candidate_files"]}
    assert expected == evaluation["source_freeze_before"] == evaluation["source_freeze_after"]
    assert all(digest(ROOT / path) == sha for path, sha in expected.items())
    assert digest(ARTIFACTS / "approved-attribute-truth-v2.json") == evaluation["truth_sha256"]
    assert evaluation["result"] == "PASS"
    originals = json.loads((ARTIFACTS / "pre-evaluation-freeze.json").read_bytes())
    protected = [row for row in originals["files"] if not row["path"].startswith("backend/tools/")]
    assert all(digest(ROOT / row["path"]) == row["sha256"] for row in protected)
    write_json(ARTIFACTS / "preservation-and-hash-verification.json", {
        "protected_files": protected, "changes": [],
        "evaluation_matches_final_candidate_before_and_after": True,
        "all_15_human_values_and_notes_preserved": True,
        "review_csv_sha256": truth["review_csv"]["sha256"],
        "truth_sha256": evaluation["truth_sha256"],
        "holdout_or_evaluator_only_read": False,
        "source_snapshots_byte_identical": True,
    })
    parent = ROOT / "debug/w1_w5_20261008_01a11796/artifacts"
    for filename in ("w2-attempts.json", "w2-public-corrected-result.json", "w2-public-corrected.log"):
        destination = ARTIFACTS / ("parent-" + filename)
        if destination.exists():
            raise FileExistsError(destination)
        shutil.copyfile(parent / filename, destination)
    history = json.loads((ARTIFACTS / "attempt-history.json").read_bytes())
    history["attempts"][2].update(exit_code=0, off_inferences=3, on_inferences=3,
                                  metrics_computed=True, output_json_created=True,
                                  result="PASS", duration_seconds=8.438)
    history["total_observed_inference_count"] = {"off": 6, "on": 3}
    history.pop("total_if_corrected_comparison_completes")
    write_json(ARTIFACTS / "attempt-history-final.json", history)
    for relative in OWNED_SOURCE:
        destination = ARTIFACTS / "final" / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            raise FileExistsError(destination)
        shutil.copyfile(ROOT / relative, destination)
        assert digest(destination) == digest(ROOT / relative)
    write_new(ARTIFACTS / "status-update-draft.md", """### W2 공개 속성 truth 동결 및 공개 비교 (2026-10-08)

- 사용자 검수 15/15을 값·notes 변경 없이 별도 승인 truth v2로 동결했다. reviewer_id 15개 모두 user-l01x, CSV SHA a4c158abe7a23e7e0111d7969dbcaf25c70ce30921a1159f6442d889c9e9e5cc. 동결 UTC 2026-10-07T18:34:11.546789Z; PNG/ROI/정책 hash와 원본 동일 source-inputs 10개 포함. 모델 초안과 검수값 차이 0/15.
- 고정 공개 F8 720p 3장 수정 비교 PASS: off/on 정답 후보 탈락 0/0, 최종 오답 0/0, top-1 3/3→3/3, 미확정 2→0. CSV truth는 모든 inference 뒤 metrics에서만 사용. 합성은 도구 시험용이고 평가 입력에서 제외. 기존 selected 필터·identity·threshold 불변, 최종 candidate hash 전후 일치.
- 최초 sandbox 호출은 import WinError5(inference0); 승인 실행은 cleanup AttributeError(off3/on0/metrics0), 실행 중 cleanup-only 소스 변경 사실 포함. 부모 승인 corrected 비교 1회(off3/on3) PASS; 전체 실제 inference off6/on3. 전체 Python/커밋은 부모가 직렬 처리. 공개 3장 결과이며 O3 승격·holdout·일반화 완료 선언은 없다. 인계: debug/scanner_o3_truth_freeze_20261008_01a11796/output.md.
""")
    write_new(ARTIFACTS / "verification.txt", """Focused loader (cwd backend):
PYTHONIOENCODING=utf-8 PYTHONDONTWRITEBYTECODE=1
py -3.11 -m unittest tests.test_student_attribute_truth_loader -v
Final result: 1/1 PASS, 0.079s; actual log focused-loader-final.log.

Corrected fixed-public comparison (root, approved execution; cwd backend):
.venv/Scripts/python.exe -m tools.evaluate_student_attribute_prefilter --truth ../debug/scanner_o3_truth_freeze_20261008_01a11796/artifacts/approved-attribute-truth-v2.json --output ../debug/scanner_o3_truth_freeze_20261008_01a11796/artifacts/public-off-on-evaluation.json
Root environment/argv/UTC receipt: parent-w2-public-corrected-result.json.
Result: exit0,8.438s,PASS; off 0/0/3/2 -> on 0/0/3/0 (candidate drop/wrong/top1/unconfirmed).
Previous failed off3 preserved in attempt-history-final.json; total off6/on3. Do not rerun.

Source syntax: PASS for the three new Python files.
git diff --no-index --check NUL <newfile>: empty diagnostics for all three (exit1 means files differ).
Final candidate SHA equality before/after/current: PASS.
Original protected source/CSV/template/README hashes: unchanged.
Source copies: byte identical, 10/10. Artifact sizes/SHA checked before output.md.

MASTER_REQUIRED: cd backend; py -3.11 -m unittest discover -s tests -v
Root uses its approved existing site-packages environment; run once after all W1-W5 sources freeze.
MASTER_REQUIRED: inspect commit-files.json, git diff --check, then root serializes explicit W2 commit.
Suggested commit message: Freeze public O3 attribute truth a4c158abe7a23e7e
No stage/commit/full suite by W2 child; no Flutter or live game changes.
""")
    write_new(ARTIFACTS / "MASTER_PROMPT.md", """# W2 인수 및 부모 후속 작업

1. output.md와 artifact-manifest.json의 모든 경로/크기/SHA 및 실제 새 source 3개와 artifacts/final 사본 동일성을 확인한다.
2. public-off-on-evaluation.json은 이미 부모 승인 corrected 비교 1회 결과다. 반복 실행하지 않는다. attempt-history-final.json은 실패 off3 및 실행 중 cleanup-only 수정 사실을 포함하며 실제 총 inference는 off6/on3이다.
3. MASTER_REQUIRED: 모든 W1-W5 source 동결 뒤 부모의 승인된 환경에서 전체 Python을 한 번 실행한다: backend cwd, py -3.11 -m unittest discover -s tests -v.
4. MASTER_REQUIRED: commit-files.json의 W2 실제 파일 목록만 명시적으로 stage하고, 다른 staged 파일을 섞지 않으며 부모가 커밋을 직렬 처리한다. 메시지에 a4c158abe7a23e7e 포함. 권장: Freeze public O3 attribute truth a4c158abe7a23e7e.
5. status-update-draft.md는 부모만 공용 status/P0-P6에 통합한다. 공개 소형 cohort PASS를 O3 승격/holdout/일반화 완료로 올리지 않는다.
""")
    write_new(ARTIFACTS / "public-evaluation-report.md", """# W2 공개 비교 결과

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
""")
    output_relative = (TASK / "output.md").relative_to(ROOT).as_posix()
    artifacts_now = [path.relative_to(ROOT).as_posix() for path in sorted(ARTIFACTS.rglob("*")) if path.is_file()]
    commit_paths = OWNED_SOURCE + [TASK.joinpath("input.md").relative_to(ROOT).as_posix()] + artifacts_now
    commit_paths += [(ARTIFACTS / "commit-files.json").relative_to(ROOT).as_posix(),
                     (ARTIFACTS / "artifact-manifest.json").relative_to(ROOT).as_posix(), output_relative]
    write_json(ARTIFACTS / "commit-files.json", {
        "commit_message": "Freeze public O3 attribute truth a4c158abe7a23e7e",
        "commit_files": sorted(set(commit_paths)), "root_serializes_stage_commit": True,
        "existing_source_files_modified": [], "new_python_source_files": OWNED_SOURCE,
        "original_prep_package_files_required_to_stage": [],
    })
    files = sorted(path for path in ARTIFACTS.rglob("*") if path.is_file())
    rows = [{"path": path.relative_to(TASK).as_posix(), "bytes": path.stat().st_size,
             "sha256": digest(path)} for path in files]
    assert all(row["bytes"] > 0 for row in rows)
    manifest_path = ARTIFACTS / "artifact-manifest.json"
    write_json(manifest_path, {"task_id": TASK.name, "artifacts": rows,
                               "self_hash_excluded": True, "output_md_written_last": True})
    manifest_record = {"path": manifest_path.relative_to(TASK).as_posix(),
                       "bytes": manifest_path.stat().st_size, "sha256": digest(manifest_path)}
    table = "\n".join(f"| `{r['path']}` | {r['bytes']} | `{r['sha256']}` |" for r in rows + [manifest_record])
    output = f"""# 작업 결과

## 작업 정보

- 작업 ID: `{TASK.name}`
- 상태: `COMPLETED` — W2 동결·공개 비교·인계 완료. 전체 Python/커밋은 부모 담당.
- 입력: `input.md`
- 승인 truth: `artifacts/approved-attribute-truth-v2.json` (v1 보존; v2는 source 사본 추가만, 값 변경 0)
- CSV SHA: `{truth['review_csv']['sha256']}`
- 동결 UTC: `{truth['frozen_at_utc']}`
- reviewer_id: 15/15 `user-l01x`. 모델 초안과 검수값 차이 0/15.

## 공개 비교

**PASS**, 공개 F8 basic 3장/1280×720의 부모 승인 corrected 비교 1회.

| 모드 | 정답 후보 탈락 | 최종 오답 | top-1 정답 | 미확정 |
|---|---:|---:|---:|---:|
| off | 0 | 0 | 3/3 | 2 |
| on | 0 | 0 | 3/3 | 0 |

기준은 §A-⑤의 탈락0·오답0·top-1 비감소·미확정 비증가 그대로다. 승인 속성 truth는
모든 inference 뒤 metrics에서만 사용했고 인식·DB·prediction에 역주입하지 않았다.
합성은 도구 시험용으로만 표시하고 평가 입력에서 제외했다. 기존 selected 필터와
일러스트 권한/threshold/identity 구현을 보존했다. O3 승격·holdout·일반화 완료 선언은 없다.

## 실행 이력 및 검증

- focused 로더 최종 1/1 PASS(0.079s), 15행·5축·값·실제 reviewer·source integrity 검증.
- sandbox 호출은 import WinError5로 inference0. 첫 부모 승인 실행은 cleanup AttributeError로
  off3/on0/metrics0/JSON0였다. cleanup-only guard를 실행 중 변경한 사실도 보존했다.
- 부모가 승인한 corrected 비교는 off3/on3, exit0/8.438s로 완료됐다. **실제 총 inference는
  off6/on3**이다. 실패를 지우거나 단일 실행으로 표현하지 않는다. 후보·기준·라벨 조정은 없다.
- 최종 candidate freeze/실행 전/실행 후/현재 SHA 모두 일치. 보호 source·원 CSV·템플릿·README
  해시 변경 0. 원 PNG 3개와 ROI/라벨 정책 hash 및 byte 동일 source-inputs 10개 포함.
- 새 Python source 3개 syntax PASS. `git diff --no-index --check`의 whitespace 진단은 빈 출력
  (exit1은 NUL과 새 파일 내용 차이). 스테이징/커밋/전체 suite는 W2 child가 하지 않았다.

## 부모 후속 작업

MASTER_REQUIRED: 전체 source 동결 뒤 `cd backend; py -3.11 -m unittest discover -s tests -v`
한 번 실행. 기존 승인된 site-packages 환경은 부모가 적용한다.

MASTER_REQUIRED: `artifacts/commit-files.json`의 실제 W2 파일만 stage/commit한다.
커밋 메시지 예: `Freeze public O3 attribute truth a4c158abe7a23e7e`.
공용 status 수정은 `artifacts/status-update-draft.md`를 부모가 통합한다.

기존 공개 소형 cohort 한계/원 capture provenance 미확인을 보존한다.
holdout/evaluator-only·게임·Flutter·RAQM·새 해상도/DPI·일반화 검증은 수행하지 않았다.
정상 sandbox 접근 거부 뒤 W2 child는 거부 경로를 재시도/우회하지 않았고,
부모의 승인된 실행 결과를 인계한다. 자동 승인 심사 거절 사건은 없다.

## 변경 파일

- 신규 `backend/tools/student_attribute_truth.py`
- 신규 `backend/tools/evaluate_student_attribute_prefilter.py`
- 신규 `backend/tests/test_student_attribute_truth_loader.py`
- 신규 본 debug 디렉터리의 실제 파일(명시 목록 `artifacts/commit-files.json`)
- 기존 파일 수정: 없음. 원 준비 패키지를 W2 commit에 추가할 필요 없음(source-inputs 사본 포함).

## 실제 산출물

`output.md`는 아래 {len(rows) + 1}개 artifacts의 존재·크기·SHA를 확인한 뒤 마지막에 썼다.
manifest는 자신의 hash 순환을 피하며 자신의 실제 hash는 아래 표에 있다.

| 경로 | 크기(B) | SHA-256 |
|---|---:|---|
{table}
"""
    write_new(TASK / "output.md", output)
    assert all((ROOT / path).is_file() for path in sorted(set(commit_paths)))
    print(json.dumps({"output_md": output_relative, "artifact_count": len(rows) + 1,
                      "output_sha256": digest(TASK / "output.md"),
                      "commit_file_count": len(set(commit_paths))}))


if __name__ == "__main__":
    main()
