<#
.SYNOPSIS
  Frontend redesign common gate (FE1-g 2026-10-06; process tests split out 2026-10-07).
  ASCII-only on purpose: Windows PowerShell 5.1 reads BOM-less files as CP949.

.DESCRIPTION
  Runs in order and keeps every output under debug\frontend_gate\<stamp>\ :
    1. flutter analyze
    2. (only with -UpdateGoldens) flutter test --update-goldens test/goldens
    3. flutter test --exclude-tags golden <unit/widget test files>     (batches of 40 files)
    4. flutter test --concurrency=1 <process test files>               (tests that start the real Python backend)
    5. flutter test test/goldens                                      (golden compare)
    6. codealmanac validate                                           (in v7)
    7. git diff --check -- .                                          (v7 scope)
  Process tests are files under test\ whose source starts the real backend (ProcessAppService, Process.start,
  ...). Running them in parallel with hundreds of widget tests, or next to golden rendering, made them time out
  under load (2026-10-06: 4 cases, 2026-10-07: 3 cases). They now run alone and one file at a time.
  A failing stage does not stop the rest. summary.txt is written at the end. Exit 1 if any stage failed.
  No commit, push, install or working-tree cleanup.

.PARAMETER UpdateGoldens
  Regenerates golden PNGs under test\goldens (first creation or an approved visual change), then compares again.

.EXAMPLE
  cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
#>
[CmdletBinding()]
param(
  [switch]$UpdateGoldens
)

# Windows PowerShell 5.1: with 'Stop', native stderr becomes a terminating error.
# Keep Continue and judge each stage by $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

# Read flutter/git UTF-8 output correctly; restore afterwards. Ignore failure on console-less hosts.
$previousOutputEncoding = $null
try {
  $previousOutputEncoding = [Console]::OutputEncoding
  [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
}
catch { }

$frontend = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$v7 = (Resolve-Path (Join-Path $frontend '..')).Path
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path $v7 "debug\frontend_gate\$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$results = New-Object System.Collections.ArrayList

function Invoke-Stage {
  param(
    [string]$Name,
    [string]$WorkDir,
    [string]$Exe,
    [string[]]$StageArgs
  )
  Write-Host ""
  Write-Host "=== $Name ===  ($Exe $($StageArgs -join ' '))" -ForegroundColor Cyan
  $log = Join-Path $outDir "$Name.log"
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $lines = New-Object System.Collections.Generic.List[string]
  $code = 0
  if (-not (Get-Command $Exe -ErrorAction SilentlyContinue)) {
    # A missing command leaves no $LASTEXITCODE and could look like a pass. Record it as a failure.
    $lines.Add("FE_GATE: command not found on PATH: $Exe")
    Write-Host "FE_GATE: command not found on PATH: $Exe" -ForegroundColor Red
    $code = 9009
  }
  else {
    Push-Location -LiteralPath $WorkDir
    try {
      $global:LASTEXITCODE = 0
      & $Exe @StageArgs 2>&1 | ForEach-Object {
        $text = $_.ToString()
        $lines.Add($text)
        Write-Host $text
      }
      $code = $LASTEXITCODE
    }
    catch {
      $lines.Add("FE_GATE: could not run '$Exe': $($_.Exception.Message)")
      Write-Host "FE_GATE: could not run '$Exe': $($_.Exception.Message)" -ForegroundColor Red
      $code = 9009
    }
    finally {
      Pop-Location
    }
  }
  $watch.Stop()
  [System.IO.File]::WriteAllLines($log, [string[]]$lines.ToArray(), $utf8)
  $row = [ordered]@{
    name    = $Name
    exit    = $code
    status  = $(if ($code -eq 0) { 'PASS' } else { 'FAIL' })
    seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1)
    detail  = (Get-StageDetail -Name $Name -Lines $lines)
  }
  [void]$results.Add($row)
  $color = $(if ($code -eq 0) { 'Green' } else { 'Red' })
  Write-Host "--- $Name : $($row.status) (exit $code, $($row.seconds)s) $($row.detail)" -ForegroundColor $color
}

function Get-StageDetail {
  param([string]$Name, $Lines)
  $all = @($Lines)
  if ($all.Count -eq 0) { return '' }
  if ($Name -eq 'flutter-analyze') {
    $hit = $all | Where-Object { $_ -match 'No issues found|issues? found' } | Select-Object -Last 1
    if ($hit) { return $hit.Trim() }
  }
  if ($Name -like 'flutter-test*') {
    # Last progress line: "00:39 +431: All tests passed!" / "+429 -2: Some tests failed."
    $hit = $all | Where-Object { $_ -match '\+\d+.*: ' } | Select-Object -Last 1
    if ($hit) {
      $passed = 0; $skipped = 0; $failed = 0
      if ($hit -match '\+(\d+)') { $passed = [int]$Matches[1] }
      if ($hit -match '~(\d+)') { $skipped = [int]$Matches[1] }
      if ($hit -match ' -(\d+)') { $failed = [int]$Matches[1] }
      return "passed=$passed skipped=$skipped failed=$failed | $($hit.Trim())"
    }
  }
  if ($Name -eq 'git-diff-check') {
    $count = @($all | Where-Object { $_ -match ':\d+: ' }).Count
    return "whitespace_findings=$count"
  }
  $last = $all | Where-Object { $_.Trim() } | Select-Object -Last 1
  if ($last) { return $last.Trim() }
  return ''
}

Write-Host "FE gate $stamp  v7=$v7  UpdateGoldens=$UpdateGoldens"
Write-Host "logs: $outDir"

Invoke-Stage -Name 'flutter-analyze' -WorkDir $frontend -Exe 'flutter' -StageArgs @('analyze')
if ($UpdateGoldens) {
  Invoke-Stage -Name 'flutter-test-update-goldens' -WorkDir $frontend -Exe 'flutter' -StageArgs @('test', '--update-goldens', 'test/goldens')
}
# Split test files: process tests (start the real Python backend) run alone, serially.
$testRoot = Join-Path $frontend 'test'
$goldenRoot = Join-Path $testRoot 'goldens'
$processPattern = 'ProcessAppService|Process\.start|PlanningProtocolClient\.start|ScannerProtocolClient\.start|BA_PLANNER_PYTHON|stdio_server'
$unitFiles = New-Object System.Collections.Generic.List[string]
$processFiles = New-Object System.Collections.Generic.List[string]
foreach ($file in (Get-ChildItem -LiteralPath $testRoot -Recurse -Filter '*_test.dart' | Sort-Object FullName)) {
  if ($file.FullName.StartsWith($goldenRoot, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
  $rel = 'test/' + $file.FullName.Substring($testRoot.Length + 1).Replace('\', '/')
  $text = [System.IO.File]::ReadAllText($file.FullName)
  if ($text -match $processPattern) { $processFiles.Add($rel) } else { $unitFiles.Add($rel) }
}
[System.IO.File]::WriteAllLines((Join-Path $outDir 'test-split.txt'), [string[]](@('# process (serial)') + $processFiles.ToArray() + @('', '# unit/widget') + $unitFiles.ToArray()), $utf8)
Write-Host ("test split: unit/widget " + $unitFiles.Count + " files, process " + $processFiles.Count + " files (see test-split.txt)")
# flutter.bat goes through cmd.exe (8191-char line limit), so pass unit files in batches.
$batchSize = 40
$batchCount = [math]::Ceiling($unitFiles.Count / $batchSize)
for ($b = 0; $b -lt $batchCount; $b++) {
  $take = [math]::Min($batchSize, $unitFiles.Count - $b * $batchSize)
  $batch = $unitFiles.GetRange($b * $batchSize, $take).ToArray()
  $stageName = $(if ($batchCount -eq 1) { 'flutter-test' } else { 'flutter-test-' + ($b + 1) })
  Invoke-Stage -Name $stageName -WorkDir $frontend -Exe 'flutter' -StageArgs (@('test', '--exclude-tags', 'golden') + $batch)
}
if ($processFiles.Count -gt 0) {
  Invoke-Stage -Name 'flutter-test-process' -WorkDir $frontend -Exe 'flutter' -StageArgs (@('test', '--exclude-tags', 'golden', '--concurrency=1') + $processFiles.ToArray())
}
Invoke-Stage -Name 'flutter-test-golden' -WorkDir $frontend -Exe 'flutter' -StageArgs @('test', 'test/goldens')
Invoke-Stage -Name 'almanac-validate' -WorkDir $v7 -Exe 'codealmanac' -StageArgs @('validate')
Invoke-Stage -Name 'git-diff-check' -WorkDir $v7 -Exe 'git' -StageArgs @('diff', '--check', '--', '.')

# --- golden list, hashes, working-tree status ---------------------------------------
$goldenDir = Join-Path $frontend 'test\goldens\baseline'
$goldenLines = New-Object System.Collections.Generic.List[string]
$goldenCount = 0
if (Test-Path -LiteralPath $goldenDir) {
  foreach ($file in (Get-ChildItem -LiteralPath $goldenDir -Filter '*.png' | Sort-Object Name)) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    $goldenLines.Add("$hash  $($file.Name)  $($file.Length)")
    $goldenCount += 1
  }
}
[System.IO.File]::WriteAllLines((Join-Path $outDir 'goldens.sha256.txt'), [string[]]$goldenLines.ToArray(), $utf8)
$failureDir = Join-Path $frontend 'test\goldens\failures'
$failureCount = 0
if (Test-Path -LiteralPath $failureDir) {
  $failureCount = @(Get-ChildItem -LiteralPath $failureDir -Filter '*.png').Count
}

$head = (& git -C $v7 rev-parse HEAD 2>$null | Out-String).Trim()
$branch = (& git -C $v7 rev-parse --abbrev-ref HEAD 2>$null | Out-String).Trim()
$goldenStatus = (& git -C $v7 status --short -- 'frontend/test/goldens' 2>$null | Out-String).Trim()
$flutterVersion = (& flutter --version 2>&1 | Select-Object -First 1 | Out-String).Trim()

# --- summary.txt -------------------------------------------------------------------
$failedStages = @($results | Where-Object { $_.exit -ne 0 })
$overall = $(if ($failedStages.Count -eq 0) { 'GREEN' } else { 'RED' })
$summary = New-Object System.Collections.Generic.List[string]
$summary.Add("FE gate summary")
$summary.Add("result         : $overall")
$summary.Add("stamp          : $stamp")
$summary.Add("mode           : $(if ($UpdateGoldens) { 'update-goldens' } else { 'compare' })")
$summary.Add("v7             : $v7")
$summary.Add("git            : $branch $head")
$summary.Add("flutter        : $flutterVersion")
$summary.Add("")
$summary.Add("stages:")
foreach ($row in $results) {
  $summary.Add(("  {0,-28} {1,-4} exit={2,-5} {3,7}s  {4}" -f $row.name, $row.status, $row.exit, $row.seconds, $row.detail))
}
$summary.Add("")
$summary.Add("goldens        : $goldenCount png in frontend\test\goldens\baseline (sha256 list: goldens.sha256.txt)")
$summary.Add("golden failures: $failureCount png in frontend\test\goldens\failures")
$summary.Add("git status goldens:")
if ($goldenStatus) {
  foreach ($line in ($goldenStatus -split "`r?`n")) { $summary.Add("  $line") }
}
else {
  $summary.Add("  (clean)")
}
$summary.Add("")
$summary.Add("logs           : $outDir")
$summaryPath = Join-Path $outDir 'summary.txt'
[System.IO.File]::WriteAllLines($summaryPath, [string[]]$summary.ToArray(), $utf8)

Write-Host ""
foreach ($line in $summary) { Write-Host $line }
if ($previousOutputEncoding) {
  try { [Console]::OutputEncoding = $previousOutputEncoding } catch { }
}
if ($overall -eq 'GREEN') {
  Write-Host "FE gate GREEN. summary: $summaryPath" -ForegroundColor Green
  exit 0
}
Write-Host "FE gate RED. summary: $summaryPath" -ForegroundColor Red
exit 1
