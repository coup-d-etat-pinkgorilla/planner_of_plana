"""Package only derived research outputs, then write output.md last (no store writes)."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import zipfile
from _research_common import ROOT, sha, load, file_record, write_new


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--task-dir', type=Path, required=True)
    ap.add_argument('--src', type=Path, required=True)
    ap.add_argument('--facts', type=Path, required=True)
    ap.add_argument('--commit', required=True)
    args = ap.parse_args()
    task, src = args.task_dir.resolve(), args.src.resolve()
    if not task.is_relative_to(ROOT / 'debug') or not src.is_relative_to(ROOT):
        raise ValueError('workspace boundary')
    facts = load(args.facts)
    artifacts = task / 'artifacts'
    with zipfile.ZipFile(artifacts / 'derived-output.zip', 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for p in sorted(src.rglob('*')):
            if p.is_file():
                archive.write(p, p.relative_to(ROOT).as_posix())
    for rel in facts['copyFiles']:
        p = ROOT / rel
        target = artifacts / 'files' / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            raise FileExistsError(target)
        shutil.copyfile(p, target)
    records = [file_record(p) for p in sorted(artifacts.rglob('*')) if p.is_file()]
    write_new(artifacts / 'manifest.json', {'artifacts': records, 'commit': args.commit,
                'onlyDerivedArtifactsCopied': True, 'outputWrittenLast': True})
    records.append(file_record(artifacts / 'manifest.json'))
    lines = [facts.get('mismatch', '불일치: 없음'), '', '# ' + facts['title'], '',
             '상태: ' + facts['status'], '', facts['conclusion'], '',
             '## 요구사항 및 검증', '', '| 항목 | 결과 | 근거 |', '|---|---|---|']
    lines += ['| ' + ' | '.join(row) + ' |' for row in facts['requirements']]
    lines += ['', '## 시도 이력', ''] + facts['attempts']
    lines += ['', '## 규모와 한계', ''] + facts['metrics']
    lines += ['', '[코드] 커밋: `' + args.commit + '` (푸시 없음; 다른 레인 파일 미포함).', '',
              '## 실제 artifacts', '', '| 경로 | bytes [표] | SHA-256 [표] |', '|---|---:|---|']
    lines += [f"| `{r['path']}` | {r['bytes']} | `{r['sha256']}` |" for r in records]
    lines += ['', '## MASTER_REQUIRED', '', facts['importCommand'], '',
              '공용 저장소 적재는 CM·사용자 실행 단계로 남겼습니다. 폴더 import가 지원되며 명령은 실행하지 않았습니다.', '',
              '## 미확정', ''] + facts['unknowns']
    lines += ['', '## 사용자용 요약', ''] + facts['userSummary']
    lines += ['', '## 다음 입력', ''] + facts.get('nextInputs', [])
    with (task / 'output.md').open('x', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print(json.dumps(file_record(task / 'output.md'), ensure_ascii=False))


if __name__ == '__main__':
    main()
