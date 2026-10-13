"""M2 release inclusion boundary, without a Flutter build or real release writes."""
from __future__ import annotations

import ast
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ReleaseDeveloperToolsExclusionTests(unittest.TestCase):
    def test_main_release_excludes_developer_entrypoints_and_store_writers(self):
        sync = ROOT / 'frontend/tool/sync_windows_release.ps1'
        developer_build = ROOT / 'frontend/tool/build_windows_developer_tools.ps1'
        shell = shutil.which('pwsh') or shutil.which('powershell.exe')
        self.assertIsNotNone(shell, 'Windows release packaging requires PowerShell')
        with tempfile.TemporaryDirectory(prefix='ba-release-boundary-') as folder:
            work = Path(folder)
            backend = work / 'backend'
            fixture_files = {
                'core/backend_process.py': b'# runtime entry\n',
                'core/client_data_store.py': (ROOT / 'backend/core/client_data_store.py').read_bytes(),
                'data/runtime.json': b'{}\n',
                'assets/runtime.bin': b'runtime asset',
                'tools/developer_tools.py': b'# developer entry must not ship\n',
                'tools/client_data_store_tools/register_client.py': b'# writer must not ship\n',
                'tools/client_data_store_tools/_common.py': b'# writer helper must not ship\n',
                'core/__pycache__/backend_process.pyc': b'cache must not ship',
                '.venv/Scripts/python.exe': b'test-only interpreter placeholder',
                'pyproject.toml': (ROOT / 'backend/pyproject.toml').read_bytes(),
            }
            for relative, raw in fixture_files.items():
                target = backend / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            script = work / 'exercise-runtime-copy.ps1'
            script.write_text(r'''
param([string]$Sync, [string]$Backend, [string]$Destination)
$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile($Sync, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$function = $tree.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Copy-BackendRuntime' }, $true)
if (-not $function) { throw 'Production Copy-BackendRuntime was not found' }
Invoke-Expression $function.Extent.Text
$backendDirectory = $Backend
Copy-BackendRuntime $Destination
$commands = @($tree.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.Extent.Text -match 'build\s+windows\s+--release' }, $true) | ForEach-Object { $_.Extent.Text })
@{ buildCommands = $commands; copied = @(Get-ChildItem -LiteralPath $Destination -File -Recurse | ForEach-Object { $_.FullName.Substring($Destination.Length + 1).Replace('\','/') }) } | ConvertTo-Json -Depth 4 -Compress
''', encoding='utf-8-sig')
            result = subprocess.run(
                [shell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script),
                 '-Sync', str(sync), '-Backend', str(backend), '-Destination', str(work / 'release-backend')],
                capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            receipt = json.loads(result.stdout.strip())
            self.assertEqual(set(receipt['copied']), {
                'core/backend_process.py', 'core/client_data_store.py', 'data/runtime.json',
                'assets/runtime.bin', '.venv/Scripts/python.exe', 'pyproject.toml',
            })
            self.assertEqual(len(receipt['buildCommands']), 1)
            command = receipt['buildCommands'][0]
            self.assertNotRegex(command, r'(?i)developer_tools|(?:^|\s)(?:-t|--target)(?:\s|=)')

            # Exercise production staging/publish as well: rebuilding the main
            # bundle must preserve the separately built developer tools bundle.
            # The fake build creates inert fixture bytes, never a real executable.
            (work / 'frontend/tool').mkdir(parents=True)
            isolated_sync = work / 'frontend/tool/sync_windows_release.ps1'
            shutil.copy2(sync, isolated_sync)
            separate = work / 'release/developer_tools/data/app.so'
            separate.parent.mkdir(parents=True)
            separate.write_bytes(b'separate developer bundle sentinel')
            (separate.parent.parent / 'ba_planner_v7.exe').write_bytes(b'developer executable sentinel')
            fake_flutter = work / 'fake-flutter.ps1'
            fake_flutter.write_text(r'''
$ErrorActionPreference = 'Stop'
if (($args -join ' ') -ne 'build windows --release') { throw 'Unexpected main build target' }
$build = Join-Path $PSScriptRoot 'frontend/build/windows/x64/runner/Release'
New-Item -ItemType Directory -Path (Join-Path $build 'data') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $build 'ba_planner_v7.exe'), 'inert main build fixture')
[IO.File]::WriteAllText((Join-Path $build 'data/app.so'), 'inert main Dart fixture')
$global:LASTEXITCODE = 0
''', encoding='utf-8-sig')
            published = subprocess.run(
                [shell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(isolated_sync),
                 '-FlutterCommand', str(fake_flutter), '-Force'],
                capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60,
            )
            self.assertEqual(published.returncode, 0, published.stdout + published.stderr)
            self.assertTrue(separate.is_file(), 'Main publish discarded release/developer_tools')
            self.assertEqual(separate.read_bytes(), b'separate developer bundle sentinel')
            self.assertEqual((separate.parent.parent / 'ba_planner_v7.exe').read_bytes(), b'developer executable sentinel')
            self.assertEqual((work / 'release/data/app.so').read_bytes(), b'inert main Dart fixture')
            self.assertEqual({p.relative_to(work / 'release/backend').as_posix() for p in (work / 'release/backend').rglob('*') if p.is_file()}, set(receipt['copied']))

        # Flutter's default target is lib/main.dart. Check its entire local source
        # closure, so an indirect import of the developer entrypoint is rejected.
        lib = ROOT / 'frontend/lib'
        package = re.search(r'^name:\s*(\S+)', (ROOT / 'frontend/pubspec.yaml').read_text(encoding='utf-8'), re.M).group(1)
        from tests.dart_import_closure import dart_local_source_closure
        visited = dart_local_source_closure(lib, package)
        self.assertNotIn((lib / 'developer_tools_main.dart').resolve(), visited)
        self.assertFalse(any('developer_tools' in p.relative_to(lib.resolve()).parts for p in visited))

        # Runtime reader remains allowed; store mutation helpers are only in tools/.
        # Reject newly introduced filesystem mutation calls in the shipped reader.
        reader = ast.parse((ROOT / 'backend/core/client_data_store.py').read_text(encoding='utf-8'))
        write_calls = {'write', 'write_text', 'write_bytes', 'mkdir', 'unlink', 'rmdir',
                       'rename', 'remove', 'makedirs', 'copy', 'copy2', 'copyfile', 'move'}
        for node in ast.walk(reader):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                self.assertNotIn(node.func.attr, write_calls)
                if node.func.attr == 'replace':
                    self.assertFalse(isinstance(node.func.value, ast.Name) and node.func.value.id in {'os', 'shutil'})
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                modules = [alias.name for alias in node.names] if isinstance(node, ast.Import) else [node.module or '']
                self.assertFalse(any('client_data_store_tools' in name or 'developer_tools' in name for name in modules))
        self.assertRegex(developer_build.read_text(encoding='utf-8'), r'(?m)flutter build windows --release -t lib/developer_tools_main\.dart')
        self.assertIn('release\\developer_tools', developer_build.read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
