<#
.SYNOPSIS
  프론트 개편 공통 gate (FE1-g, 2026-10-06).

.DESCRIPTION
  차례로 실행하고 모든 출력을 debug\frontend_gate\<시각>\ 에 남긴다.
    1. flutter analyze
    2. (-UpdateGoldens 일 때만) flutter test --update-goldens test/goldens
    3. flutter test --exclude-tags golden   (golden 외 전체)
    4. flutter test test/goldens            (golden 비교)
    5. codealmanac validate                 (v7 폴더에서)
    6. git diff --check -- .                (v7 폴더 범위)
  3과 4를 나눠서 차례로 돌린다. golden 렌더링을 실제 Python 프로세스 E2E 테스트와
  병렬로 돌리면 E2E 요청이 시간 초과로 실패했다(2026-10-06, 4건).
  한 단계가 실패해도 나머지를 계속 돌리고, 끝에 summary.txt를 쓴다.
  하나라도 실패하면 종료 코드 1, 모두 통과하면 0.
  커밋·push·설치·작업트리 정리는 하지 않는다.

.PARAMETER UpdateGoldens
  test\goldens 아래 golden PNG를 현재 화면으로 다시 만든다(첫 생성 또는 승인된 시각 변경).
  만든 뒤 4단계가 같은 PNG와 다시 비교하므로 재현성도 함께 확인된다.

.EXAMPLE
  cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
  powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
#>
[CmdletBinding()]
param(
  [switch]$UpdateGoldens
)

# Windows PowerShell 5.1: 'Stop'이면 네이티브 명령의 stderr가 종료 오류로 바뀐다.
# 그래서 Continue로 두고 각 단계는 $LASTEXITCODE로 판정한다.
$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

# flutter·git 출력(UTF-8)을 깨지지 않게 읽는다. 끝나면 원래 값으로 돌린다.
# 콘솔이 없는 호스트에서는 설정이 실패할 수 있으므로 무시한다.
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
    # 명령이 없으면 & 호출이 $LASTEXITCODE를 남기지 않아 통과로 보일 수 있다. 실패로 기록한다.
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
    # 마지막 진행 줄: "00:39 +431: All tests passed!" / "+429 -2: Some tests failed."
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
Invoke-Stage -Name 'flutter-test' -WorkDir $frontend -Exe 'flutter' -StageArgs @('test', '--exclude-tags', 'golden')
Invoke-Stage -Name 'flutter-test-golden' -WorkDir $frontend -Exe 'flutter' -StageArgs @('test', 'test/goldens')
Invoke-Stage -Name 'almanac-validate' -WorkDir $v7 -Exe 'codealmanac' -StageArgs @('validate')
Invoke-Stage -Name 'git-diff-check' -WorkDir $v7 -Exe 'git' -StageArgs @('diff', '--check', '--', '.')

# --- golden 목록과 해시, 작업트리 상태 ---------------------------------------------
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
