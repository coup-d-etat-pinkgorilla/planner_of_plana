<#
fe_commit.ps1 - frontend redesign slice commit helper (orchestrator, 2026-10-06)
ASCII-only on purpose: Windows PowerShell 5.1 reads BOM-less files as the ANSI code page (CP949),
which breaks non-ASCII string literals. Keep this file ASCII.

Workers have no shell, and some files carry uncommitted changes from before checkpoint C, so a plain
`git add` would mix them. The worker saves a copy of each file before editing it and writes a commit
list at the end. This script uses both to stage only what the slice changed, then commits.
The working tree is never modified. Nothing is pushed.

Method: per file, `git merge-file` with base = pre copy, ours = HEAD, theirs = slice end content.
The result ("HEAD + this slice") goes into the index only (hash-object + update-index).
It stops only when an existing uncommitted change and the slice change touch the same lines.

Worker output (slice folder = debug/frontend_<slice>/, e.g. debug/frontend_fe1b/)
  pre/<v7 relative path>  copy taken before editing (one per "modified" file)
  commit.json             {
                            "slice": "FE1-b",
                            "message": ["FE1-b: ...", "", "body", ...],
                            "modified": ["frontend/lib/ui/widgets/plan_section_layout.dart", ...],
                            "added":    ["frontend/lib/ui/geometry/diagonal_geometry.dart", ...],
                            "status":   true
                          }
  status true -> almanac/workflows/frontend-redesign-status.md is committed whole (worker-owned doc).

Optional keys (orchestrator only)
  "whole":          ["path"]            tracked file known to have no prior changes; staged as in the working tree.
  "snapshot":       {"path": "source"}  index content of path = whole content of source (v7 relative). No merge.
                                        Used to commit prior uncommitted work as its own commit. EOL/BOM follow HEAD.
  "optional_added": ["path"]            add if untracked, skip if already tracked (binary ok).
  "post_dir":       "debug/frontend_fe1b/pre"
                                        when the next slice is already in progress: a file found here is used as
                                        "this slice's end content" instead of the working tree
                                        (next slice's pre copy = this slice's end).
  "inspect":        ["path"]            DryRun review only: drops HEAD and working copies into the run folder.

Usage (from the v7 folder)
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1b -DryRun
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1b

Checks
  - index must be empty.
  - gate summary (latest or -GateSummary) is GREEN and newer than every file taken from the working tree.
  - "added" files must be untracked.
  - after staging, files whose pre copy equaled HEAD and whose content came from the working tree must have
    no working-tree diff; otherwise the index is reset and the script stops.
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

# Run git directly and read stdout as bytes (PowerShell pipes decode with the code page).
function Git-Run([string[]]$GitArgs, [switch]$AllowFail, [string]$Cwd = '') {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.WorkingDirectory = $(if ($Cwd) { $Cwd } else { $v7 })
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
  if ($err) {
    # EOL conversion notices are not errors; only count them.
    $errLines = @($err -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
    $eol = @($errLines | Where-Object { $_ -match 'LF will be replaced by CRLF|CRLF will be replaced by LF' })
    $rest = @($errLines | Where-Object { $_ -notmatch 'LF will be replaced by CRLF|CRLF will be replaced by LF' })
    if ($eol.Count -gt 0) { Say ("  stderr: " + $eol.Count + " EOL conversion notice line(s) (not errors)") }
    if ($rest.Count -gt 0) { Say ("  stderr: " + ($rest -join "`n")) }
  }
  if ($p.ExitCode -ne 0 -and -not $AllowFail) { throw ("git failed (exit " + $p.ExitCode + "): git " + $psi.Arguments + "`n" + $err) }
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
function V7Path([string]$rel) { return (Join-Path $v7 ($rel -replace '/', '\')) }
function Safe([string]$rel) { return ($rel -replace '[/\\]', '_') }
# Write LF-normalized text using the HEAD blob's EOL/BOM convention.
function Write-LikeHead([string]$text, [byte[]]$headBytes, [string]$path) {
  $headRaw = $utf8.GetString($headBytes)
  if ($headRaw.Contains("`r`n")) { $text = $text.Replace("`n", "`r`n") }
  [System.IO.File]::WriteAllText($path, $text, $utf8)
  if ($headBytes.Length -ge 3 -and $headBytes[0] -eq 0xEF -and $headBytes[1] -eq 0xBB -and $headBytes[2] -eq 0xBF) {
    $mb = [System.IO.File]::ReadAllBytes($path); [System.IO.File]::WriteAllBytes($path, ([byte[]](0xEF, 0xBB, 0xBF) + $mb))
  }
}

Say "=== fe_commit.ps1 slice=$Slice  v7=$v7"
if (-not (Test-Path $manifestPath)) { throw "commit.json not found: $manifestPath" }
$m = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$modified = @($m.modified | Where-Object { $_ })
$added = @($m.added | Where-Object { $_ })
$whole = @($m.whole | Where-Object { $_ })
$optAdded = @($m.optional_added | Where-Object { $_ })
$inspect = @($m.inspect | Where-Object { $_ })
$snapshot = @()
if ($null -ne $m.snapshot) { foreach ($p in $m.snapshot.PSObject.Properties) { $snapshot += [pscustomobject]@{ Rel = $p.Name; Src = [string]$p.Value } } }
$postDir = ''
if ($m.post_dir) { $postDir = V7Path ([string]$m.post_dir) }
$withStatus = $true
if ($null -ne $m.status) { $withStatus = [bool]$m.status }
$msgLines = @($m.message)
if ($msgLines.Count -eq 0 -or -not $msgLines[0]) { throw 'commit.json message is empty.' }
Say ("modified " + $modified.Count + " / added " + $added.Count + " / snapshot " + $snapshot.Count + " / optional_added " + $optAdded.Count + " / whole " + $whole.Count + " / status " + $withStatus)
if ($postDir) { Say ("post_dir: " + $postDir + $(if (Test-Path $postDir) { '' } else { ' (not present yet -> working tree used)' })) }

# Slice end content: the next slice pre copy if present, else the working tree.
function Post-Source([string]$rel) {
  if ($postDir) {
    $c = Join-Path $postDir ($rel -replace '/', '\')
    if (Test-Path $c) { return [pscustomobject]@{ Path = $c; FromPost = $true } }
  }
  return [pscustomobject]@{ Path = (V7Path $rel); FromPost = $false }
}

$prefix = (Git-Run @('rev-parse', '--show-prefix')).Text.Trim().TrimEnd('/')
$top = (Git-Run @('rev-parse', '--show-toplevel')).Text.Trim()
function TopRel([string]$rel) { if ($prefix) { return "$prefix/$rel" } else { return $rel } }
function Head-Mode([string]$rel) {
  $ls = (Git-Run @('ls-files', '-s', '--', $rel)).Text.Trim()
  $mode = ($ls -split '\s+')[0]
  if (-not $mode) { $mode = '100644' }
  return $mode
}

# 0. index must be empty
$staged = Git-Lines @('diff', '--cached', '--name-only')
if ($staged.Count -gt 0) { throw ("Files are already staged. Clear the index and rerun:`n" + ($staged -join "`n")) }

# 1. gate
if (-not $GateSummary) {
  $latest = Get-ChildItem (Join-Path $v7 'debug\frontend_gate') -Directory | Sort-Object Name | Select-Object -Last 1
  if (-not $latest) { throw 'No fe_gate run found. Run frontend\tool\fe_gate.ps1 first.' }
  $GateSummary = Join-Path $latest.FullName 'summary.txt'
}
if (-not (Test-Path $GateSummary)) { throw "gate summary not found: $GateSummary" }
$sum = Get-Content -Path $GateSummary -Encoding UTF8
$resLine = [string]($sum | Where-Object { $_ -match '^result\s*:' } | Select-Object -First 1)
Say "gate: $GateSummary / $resLine"
if ($resLine -notmatch 'GREEN') { throw 'Gate is not GREEN. Nothing staged.' }
$sumTime = (Get-Item $GateSummary).LastWriteTime
# Only files taken from the working tree are time-checked. The status doc is excluded (it records gate results).
# post_dir copies may be newer than the gate but hold the earlier working-tree content; logged, not checked.
$timeChecked = @()
foreach ($rel in @($modified + $added)) { $s = Post-Source $rel; if (-not $s.FromPost) { $timeChecked += $s.Path } else { Say "using post_dir copy: $rel" } }
foreach ($x in $snapshot) { $timeChecked += (V7Path $x.Src) }
foreach ($p in $timeChecked) {
  if (-not (Test-Path $p)) { throw "file not found: $p" }
  $t = (Get-Item $p).LastWriteTime
  if ($t -gt $sumTime) { throw "file changed after the gate ($sumTime): $p ($t). Rerun fe_gate.ps1 or check post_dir." }
}

# 2. added files must be untracked
foreach ($rel in $added) {
  $s = Post-Source $rel
  if (-not (Test-Path $s.Path)) { throw "added file not found: $rel" }
  $t = Git-Lines @('ls-files', '--', $rel)
  if ($t.Count -gt 0) { throw "tracked file listed as added (move it to modified and keep a pre copy): $rel" }
}
$optToAdd = @()
foreach ($rel in $optAdded) {
  if (-not (Test-Path (V7Path $rel))) { throw "optional_added file not found: $rel" }
  $t = Git-Lines @('ls-files', '--', $rel)
  if ($t.Count -gt 0) { Say "already tracked (skipped): $rel"; continue }
  $ot = (Get-Item (V7Path $rel)).LastWriteTime
  if ($ot -gt $sumTime) { throw "optional_added file changed after the gate ($sumTime): $rel ($ot)." }
  Say "will add (untracked): $rel"; $optToAdd += $rel
}

# 3a. modified -> 3-way merge builds "HEAD + slice change" (index untouched yet)
$plan = @()
$expectClean = @{}
foreach ($rel in $modified) {
  $pre = Join-Path $preDir ($rel -replace '/', '\')
  $src = Post-Source $rel
  if (-not (Test-Path $pre)) { throw "pre copy not found: $pre" }
  if (-not (Test-Path $src.Path)) { throw "file not found: $($src.Path)" }
  $preText = Norm ([System.IO.File]::ReadAllBytes($pre))
  $curText = Norm ([System.IO.File]::ReadAllBytes($src.Path))
  $headR = Git-Run @('show', ("HEAD:./" + $rel)) -AllowFail
  if ($headR.Code -ne 0) { throw "file not in HEAD must be listed as added, not modified: $rel" }
  $headText = Norm $headR.Bytes
  $expectClean[$rel] = (($headText -eq $preText) -and -not $src.FromPost)
  if ($preText -eq $curText) { Say "no change (skipped): $rel"; continue }
  $safe = Safe $rel
  $o = Join-Path $work ($safe + '.head'); $b = Join-Path $work ($safe + '.pre'); $t = Join-Path $work ($safe + '.cur')
  [System.IO.File]::WriteAllText($o, $headText, $utf8)
  [System.IO.File]::WriteAllText($b, $preText, $utf8)
  [System.IO.File]::WriteAllText($t, $curText, $utf8)
  $mr = Git-Run @('merge-file', '-p', '-L', 'HEAD', '-L', 'pre', '-L', 'slice', $o, $b, $t) -AllowFail
  if ($mr.Code -ne 0) {
    [System.IO.File]::WriteAllBytes((Join-Path $work ($safe + '.conflict')), $mr.Bytes)
    throw "merge conflict ($($mr.Code) hunk(s)): $rel - a prior uncommitted change and the slice change touch the same lines. Nothing staged. Send the .conflict file in $work to the orchestrator."
  }
  $mf = Join-Path $work ($safe + '.merged')
  Write-LikeHead ($utf8.GetString($mr.Bytes)) $headR.Bytes $mf
  $plan += [pscustomobject]@{ Rel = $rel; Mode = (Head-Mode $rel); File = $mf; Add = $false }
}

# 3b. snapshot -> whole source content
foreach ($x in $snapshot) {
  $headR = Git-Run @('show', ("HEAD:./" + $x.Rel)) -AllowFail
  if ($headR.Code -ne 0) { throw "snapshot target not in HEAD (list it as added): $($x.Rel)" }
  $srcPath = V7Path $x.Src
  $safe = Safe $x.Rel
  [System.IO.File]::WriteAllText((Join-Path $work ($safe + '.head')), (Norm $headR.Bytes), $utf8)
  $snapText = Norm ([System.IO.File]::ReadAllBytes($srcPath))
  [System.IO.File]::WriteAllText((Join-Path $work ($safe + '.snap')), $snapText, $utf8)
  if ((Norm $headR.Bytes) -eq $snapText) { Say "snapshot equals HEAD (skipped): $($x.Rel)"; continue }
  $sf = Join-Path $work ($safe + '.snapstaged')
  Write-LikeHead $snapText $headR.Bytes $sf
  $plan += [pscustomobject]@{ Rel = $x.Rel; Mode = (Head-Mode $x.Rel); File = $sf; Add = $false }
  Say "snapshot ready: $($x.Rel) <- $($x.Src)"
}

# 3c. added files with a post_dir copy are staged from that copy
$addedFromWork = @()
foreach ($rel in $added) {
  $s = Post-Source $rel
  if ($s.FromPost) { $plan += [pscustomobject]@{ Rel = $rel; Mode = '100644'; File = $s.Path; Add = $true; Filtered = $true } }
  else { $addedFromWork += $rel }
}

# 3d. inspect (review copies only)
foreach ($rel in $inspect) {
  $safe = Safe $rel
  $headR = Git-Run @('show', ("HEAD:./" + $rel)) -AllowFail
  if ($headR.Code -eq 0) { [System.IO.File]::WriteAllText((Join-Path $work ($safe + '.inspect.head')), (Norm $headR.Bytes), $utf8) }
  $wp = V7Path $rel
  if (Test-Path $wp) { [System.IO.File]::WriteAllText((Join-Path $work ($safe + '.inspect.work')), (Norm ([System.IO.File]::ReadAllBytes($wp))), $utf8) }
}
if ($inspect.Count -gt 0 -or $snapshot.Count -gt 0) {
  $st = Git-Run @('status', '--porcelain=v1', '-uall', '--', 'frontend/lib', 'frontend/test', 'frontend/assets/fonts', 'frontend/pubspec.yaml')
  [System.IO.File]::WriteAllBytes((Join-Path $work 'frontend-status.txt'), $st.Bytes)
}

Say ("ready: merge/snapshot " + $plan.Count + ", added from working tree " + $addedFromWork.Count + ", optional " + $optToAdd.Count)
if ($DryRun) { Say 'DryRun: checks passed. Nothing staged.'; Say "review files: $work"; exit 0 }

# 4. stage
$restore = @($modified + $added + $whole + $optToAdd + @($snapshot | ForEach-Object { $_.Rel }))
try {
  foreach ($x in $plan) {
    if ($x.Filtered) { $sha = (Git-Run @('hash-object', '-w', ('--path=' + $x.Rel), $x.File)).Text.Trim() }
    else { $sha = (Git-Run @('hash-object', '-w', '--no-filters', $x.File)).Text.Trim() }
    $ui = @('update-index')
    if ($x.Add) { $ui += '--add' }
    $ui += @('--cacheinfo', ($x.Mode + ',' + $sha + ',' + (TopRel $x.Rel)))
    Git-Run $ui -Cwd $top | Out-Null
  }
  if ($addedFromWork.Count -gt 0) { Git-Run (@('add', '--') + $addedFromWork) | Out-Null }
  if ($optToAdd.Count -gt 0) { Git-Run (@('add', '--') + $optToAdd) | Out-Null }
  if ($whole.Count -gt 0) { Git-Run (@('add', '--') + $whole) | Out-Null }
} catch {
  Git-Run (@('reset', '-q', '--') + $restore) -AllowFail | Out-Null
  throw
}

# 5. verify
$keptPrior = @()
if ($modified.Count -gt 0) {
  $left = Git-Lines (@('diff', '--name-only', '--') + $modified)
  foreach ($rel in $modified) {
    $hasLeft = $left -contains (TopRel $rel)
    if ($expectClean[$rel] -and $hasLeft) {
      Git-Run (@('reset', '-q', '--') + $restore) | Out-Null
      throw "unexpected: $rel had no prior change but still differs from the index after staging. Index reset."
    }
    if ($hasLeft) { $keptPrior += $rel }
  }
}
if ($keptPrior.Count -gt 0) { Say ("working-tree diffs left in place (prior uncommitted or next-slice changes): " + ($keptPrior -join ', ')) }
$cachedNow = Git-Lines @('diff', '--cached', '--name-only')
if ($cachedNow.Count -eq 0 -and -not $withStatus) { Say 'Nothing to commit.'; exit 0 }

# 6. status
if ($withStatus) {
  $statusFull = Join-Path $v7 $statusDoc
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  $block = "`n### $($m.slice) commit record ($stamp, written by fe_commit.ps1)`n`n- gate: $GateSummary ($($resLine.Trim()))`n- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: " + $(if ($keptPrior.Count) { $keptPrior -join ', ' } else { 'none' }) + "`n"
  [System.IO.File]::AppendAllText($statusFull, $block, $utf8)
  Git-Run @('add', '--', $statusDoc) | Out-Null
}

# 7. commit
$msg = (($msgLines | ForEach-Object { [string]$_ }) -join "`n").TrimEnd() + "`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_01UaZ2mrTb3dngp8E3h8jpFB`n"
$msgFile = Join-Path $work 'message.txt'
[System.IO.File]::WriteAllText($msgFile, $msg, $utf8)
Git-Run @('commit', '-F', $msgFile) | Out-Null
$sha = (Git-Run @('rev-parse', 'HEAD')).Text.Trim()
Say "committed: $sha"
Say ((Git-Run @('show', '--stat', '--oneline', 'HEAD')).Text)
Say "log: $log"
