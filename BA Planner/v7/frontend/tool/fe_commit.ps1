<#
fe_commit.ps1 — 프론트 개편 slice 커밋 도우미 (오케스트레이터 작성, 2026-10-06)

워커는 셸이 없어 커밋할 수 없고, 일부 파일에는 C 이전부터 남은 미커밋 변경이 있어 파일째 `git add` 하면 섞인다.
그래서 워커는 slice를 시작할 때 고칠 파일의 사본을 남기고, 끝날 때 커밋 목록을 적는다. 이 스크립트는 그 둘로
"이 slice가 바꾼 부분만" index에 올려 커밋한다. 작업트리는 건드리지 않는다. push는 하지 않는다.

방식(2026-10-06 개정): 패치 대신 3-way 병합. 파일마다 base = 고치기 전 사본, ours = HEAD, theirs = 지금 파일로
`git merge-file`을 돌려 "HEAD + 이 slice의 변경"을 만들고, 그 내용을 index에만 넣는다(`hash-object` + `update-index`).
기존 미커밋 변경이 slice 변경과 같은 줄을 건드린 경우에만 충돌로 멈춘다.

워커가 남기는 것 (slice 폴더 = debug/frontend_<slice>/ , 예: debug/frontend_fe1b/)
  pre/<v7 기준 경로>   고치기 전 사본 (modified에 적은 파일마다 하나)
  commit.json          {
                         "slice": "FE1-b",
                         "message": ["FE1-b: ...", "", "본문 줄", ...],
                         "modified": ["frontend/lib/ui/widgets/plan_section_layout.dart", ...],
                         "added":    ["frontend/lib/ui/geometry/diagonal_geometry.dart", ...],
                         "status":   true,
                         "whole":    ["AGENTS.md"]      (선택) 기존 미커밋 변경이 없다고 확인된 추적 파일을 통째로 올린다
                       }
  status가 true면 almanac/workflows/frontend-redesign-status.md 전체를 함께 커밋한다(워커 소유 문서).

사용 (v7 폴더에서)
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1b -DryRun
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1b

검사
  - index가 비어 있어야 한다.
  - 가장 최근 fe_gate summary(또는 -GateSummary)가 GREEN이고, 커밋할 파일들보다 나중에 만들어졌어야 한다.
  - added 파일은 아직 추적되지 않은 파일이어야 한다.
  - 적용 뒤, 고치기 전 사본이 HEAD와 같던 파일은 작업트리와 index가 같아야 한다. 다르던 파일은 그 차이(기존 미커밋 변경)가
    작업트리에 남는 것이 정상이며 목록으로 보여 준다. 예상과 다르면 index를 되돌리고 멈춘다.
#>
param(
  [Parameter(Mandatory = $true)][string]$Slice,
  [string]$GateSummary = '',
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$v7 = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sliceKey = $Slice.ToLower().Replace('-', '')
$dir = Join-Path $v7 ("debug\frontend_" + $sliceKey)
$preDir = Join-Path $dir 'pre'
$manifestPath = Join-Path $dir 'commit.json'
$work = Join-Path $dir ('commit_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$log = Join-Path $work 'run.log'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$statusDoc = 'almanac/workflows/frontend-redesign-status.md'

function Say([string]$m) { Write-Host $m; [System.IO.File]::AppendAllText($log, $m + "`r`n", $utf8) }

# git을 직접 실행해 stdout을 바이트로 받는다(PowerShell 파이프는 코드페이지로 한글을 깨뜨린다).
function Git-Run([string[]]$GitArgs, [switch]$AllowFail) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.WorkingDirectory = $v7
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $quoted = $GitArgs | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }
  $psi.Arguments = ($quoted -join ' ')
  $p = [System.Diagnostics.Process]::Start($psi)
  $ms = New-Object System.IO.MemoryStream
  $errTask = $p.StandardError.ReadToEndAsync()
  $p.StandardOutput.BaseStream.CopyTo($ms)
  $p.WaitForExit()
  $err = $errTask.Result
  $bytes = $ms.ToArray()
  $text = $utf8.GetString($bytes)
  Say ("git " + $psi.Arguments + "  -> exit " + $p.ExitCode)
  if ($err) { Say ("  stderr: " + $err.Trim()) }
  if ($p.ExitCode -ne 0 -and -not $AllowFail) { throw ("git 실패(exit " + $p.ExitCode + "): git " + $psi.Arguments + "`n" + $err) }
  return [pscustomobject]@{ Code = $p.ExitCode; Bytes = $bytes; Text = $text; Err = $err }
}
function Git-Lines([string[]]$GitArgs) {
  $r = Git-Run $GitArgs
  return @($r.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
function Norm([byte[]]$b) {
  $t = $utf8.GetString($b)
  if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
  return $t.Replace("`r`n", "`n")
}

Say "=== fe_commit.ps1 slice=$Slice  v7=$v7"
if (-not (Test-Path $manifestPath)) { throw "commit.json이 없습니다: $manifestPath" }
$m = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$modified = @($m.modified | Where-Object { $_ })
$added = @($m.added | Where-Object { $_ })
$withStatus = $true
if ($null -ne $m.status) { $withStatus = [bool]$m.status }
$msgLines = @($m.message)
if ($msgLines.Count -eq 0 -or -not $msgLines[0]) { throw 'commit.json의 message가 비어 있습니다.' }
Say ("modified " + $modified.Count + " / added " + $added.Count + " / status " + $withStatus)

$prefix = (Git-Run @('rev-parse', '--show-prefix')).Text.Trim().TrimEnd('/')
$dirArg = @(); if ($prefix) { $dirArg = @("--directory=$prefix") }

# 0. index 비어 있음
$staged = Git-Lines @('diff', '--cached', '--name-only')
if ($staged.Count -gt 0) { throw ("이미 stage된 파일이 있습니다. 비운 뒤 다시 실행하십시오:`n" + ($staged -join "`n")) }

# 1. gate
$allFiles = @($modified + $added)
if ($withStatus) { $allFiles += $statusDoc }
if (-not $GateSummary) {
  $latest = Get-ChildItem (Join-Path $v7 'debug\frontend_gate') -Directory | Sort-Object Name | Select-Object -Last 1
  if (-not $latest) { throw 'fe_gate 실행 기록이 없습니다. 먼저 frontend\tool\fe_gate.ps1을 실행하십시오.' }
  $GateSummary = Join-Path $latest.FullName 'summary.txt'
}
if (-not (Test-Path $GateSummary)) { throw "gate summary가 없습니다: $GateSummary" }
$sum = Get-Content -Path $GateSummary -Encoding UTF8
$resLine = [string]($sum | Where-Object { $_ -match '^result\s*:' } | Select-Object -First 1)
Say "gate: $GateSummary / $resLine"
if ($resLine -notmatch 'GREEN') { throw 'gate가 GREEN이 아닙니다. 아무것도 stage하지 않았습니다.' }
$sumTime = (Get-Item $GateSummary).LastWriteTime
# status 문서는 gate 결과를 적느라 gate 뒤에 바뀌는 것이 정상이므로 시각 비교에서 뺀다.
$codeNewest = (@($modified + $added) | ForEach-Object { (Get-Item (Join-Path $v7 $_)).LastWriteTime } | Sort-Object | Select-Object -Last 1)
if ($codeNewest -and $codeNewest -gt $sumTime) { throw "gate($sumTime)보다 나중에 바뀐 코드가 있습니다($codeNewest). fe_gate.ps1을 다시 실행하십시오." }

# 2. added는 아직 추적되지 않아야 한다
$whole = @($m.whole | Where-Object { $_ })
foreach ($rel in $added) {
  if (-not (Test-Path (Join-Path $v7 $rel))) { throw "added 파일이 없습니다: $rel" }
  $t = Git-Lines @('ls-files', '--', $rel)
  if ($t.Count -gt 0) { throw "이미 추적 중인 파일이 added에 있습니다(modified로 옮기고 사본을 두십시오): $rel" }
}

# 3. modified → 3-way 병합으로 "HEAD + slice 변경"을 만든다(아직 index는 건드리지 않음)
$top = (Git-Run @('rev-parse', '--show-toplevel')).Text.Trim()
$plan = @()
$headSame = @{}
foreach ($rel in $modified) {
  $pre = Join-Path $preDir ($rel -replace '/', '\')
  $cur = Join-Path $v7 ($rel -replace '/', '\')
  if (-not (Test-Path $pre)) { throw "고치기 전 사본이 없습니다: $pre" }
  if (-not (Test-Path $cur)) { throw "파일이 없습니다: $cur" }
  $preText = Norm ([System.IO.File]::ReadAllBytes($pre))
  $curText = Norm ([System.IO.File]::ReadAllBytes($cur))
  $headR = Git-Run @('show', ("HEAD:./" + $rel)) -AllowFail
  if ($headR.Code -ne 0) { throw "HEAD에 없는 파일은 modified가 아니라 added에 적어야 합니다: $rel" }
  $headRaw = $utf8.GetString($headR.Bytes)
  $headText = Norm $headR.Bytes
  $headSame[$rel] = ($headText -eq $preText)
  if ($preText -eq $curText) { Say "변경 없음(건너뜀): $rel"; continue }
  $safe = ($rel -replace '[/\\]', '_')
  $o = Join-Path $work ($safe + '.head'); $b = Join-Path $work ($safe + '.pre'); $t = Join-Path $work ($safe + '.cur')
  [System.IO.File]::WriteAllText($o, $headText, $utf8)
  [System.IO.File]::WriteAllText($b, $preText, $utf8)
  [System.IO.File]::WriteAllText($t, $curText, $utf8)
  $mr = Git-Run @('merge-file', '-p', '-L', 'HEAD', '-L', 'pre', '-L', 'slice', $o, $b, $t) -AllowFail
  if ($mr.Code -ne 0) {
    [System.IO.File]::WriteAllBytes((Join-Path $work ($safe + '.conflict')), $mr.Bytes)
    throw "병합 충돌($($mr.Code)건): $rel — 기존 미커밋 변경과 slice 변경이 같은 줄을 건드렸습니다. 아무것도 stage하지 않았습니다. $work 의 .conflict 파일을 오케스트레이터에게 보내 주십시오."
  }
  $merged = $utf8.GetString($mr.Bytes)
  if ($headRaw.Contains("`r`n")) { $merged = $merged.Replace("`n", "`r`n") }
  $mf = Join-Path $work ($safe + '.merged')
  [System.IO.File]::WriteAllText($mf, $merged, $utf8)
  if ($headR.Bytes.Length -ge 3 -and $headR.Bytes[0] -eq 0xEF -and $headR.Bytes[1] -eq 0xBB -and $headR.Bytes[2] -eq 0xBF) {
    $mb = [System.IO.File]::ReadAllBytes($mf); [System.IO.File]::WriteAllBytes($mf, ([byte[]](0xEF, 0xBB, 0xBF) + $mb))
  }
  $ls = (Git-Run @('ls-files', '-s', '--', $rel)).Text.Trim()
  $mode = ($ls -split '\s+')[0]
  if (-not $mode) { $mode = '100644' }
  $topRel = if ($prefix) { "$prefix/$rel" } else { $rel }
  $plan += [pscustomobject]@{ Rel = $rel; TopRel = $topRel; Mode = $mode; File = $mf }
}
Say ("병합 준비: " + $plan.Count + "개 파일")
if ($DryRun) { Say 'DryRun: 검사 통과. 아무것도 stage하지 않았습니다.'; exit 0 }

# 4. stage
$restore = @($modified + $added + $whole)
foreach ($x in $plan) {
  $sha = (Git-Run @('hash-object', '-w', '--no-filters', $x.File)).Text.Trim()
  $saveWd = $v7; $v7 = $top
  try { Git-Run @('update-index', '--cacheinfo', ($x.Mode + ',' + $sha + ',' + $x.TopRel)) | Out-Null } finally { $v7 = $saveWd }
}
if ($added.Count -gt 0) { Git-Run (@('add', '--') + $added) | Out-Null }
if ($whole.Count -gt 0) { Git-Run (@('add', '--') + $whole) | Out-Null }

# 5. 검사
$left = Git-Lines (@('diff', '--name-only', '--') + $modified)
$keptPrior = @()
foreach ($rel in $modified) {
  $topRel = if ($prefix) { "$prefix/$rel" } else { $rel }
  $hasLeft = $left -contains $topRel
  if ($headSame[$rel] -and $hasLeft) {
    Git-Run (@('reset', '-q', '--') + $restore) | Out-Null
    throw "예상과 다릅니다: $rel 은 기존 변경이 없었는데 stage 뒤에도 작업트리 차이가 남습니다. index를 되돌렸습니다."
  }
  if ($hasLeft) { $keptPrior += $rel }
}
if ($keptPrior.Count -gt 0) { Say ("작업트리에 남긴 기존 미커밋 변경: " + ($keptPrior -join ', ')) }
$cachedNow = Git-Lines @('diff', '--cached', '--name-only')
if ($cachedNow.Count -eq 0 -and -not $withStatus) { Say '올릴 변경이 없습니다. 커밋하지 않습니다.'; exit 0 }

# 7. status
if ($withStatus) {
  $statusFull = Join-Path $v7 $statusDoc
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $block = "`n### $($m.slice) 커밋 기록 ($stamp, fe_commit.ps1 자동 기록)`n`n- gate: $GateSummary ($($resLine.Trim()))`n- 커밋 방식: 고치기 전 사본·HEAD·현재 파일 3-way 병합 결과를 index에만 올림. 작업트리에 남긴 기존 변경: " + $(if ($keptPrior.Count) { $keptPrior -join ', ' } else { '없음' }) + "`n"
  [System.IO.File]::AppendAllText($statusFull, $block, $utf8)
  Git-Run @('add', '--', $statusDoc) | Out-Null
}

# 8. commit
$msg = (($msgLines | ForEach-Object { [string]$_ }) -join "`n").TrimEnd() + "`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01UaZ2mrTb3dngp8E3h8jpFB`n"
$msgFile = Join-Path $work 'message.txt'
[System.IO.File]::WriteAllText($msgFile, $msg, $utf8)
Git-Run @('commit', '-F', $msgFile) | Out-Null
$sha = (Git-Run @('rev-parse', 'HEAD')).Text.Trim()
Say "커밋 완료: $sha"
Git-Run @('show', '--stat', '--oneline', 'HEAD') | ForEach-Object { Say $_.Text }
Say "기록: $log"
