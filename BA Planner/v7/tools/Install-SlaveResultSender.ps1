[CmdletBinding()]
param(
    [string]$RepositoryRoot = '',

    [string]$InstallDirectory = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$resolvedRepository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$canonicalScript = Join-Path $resolvedRepository 'tools\Send-SlaveResult.ps1'
if (-not (Test-Path -LiteralPath $canonicalScript -PathType Leaf)) {
    throw "Missing canonical slave sender: $canonicalScript"
}

if ([string]::IsNullOrWhiteSpace($InstallDirectory)) {
    $InstallDirectory = Join-Path $env:USERPROFILE '.codex\ba-planner-slave'
}
if (-not (Test-Path -LiteralPath $InstallDirectory)) {
    New-Item -ItemType Directory -Path $InstallDirectory | Out-Null
}
$resolvedInstallDirectory = (Resolve-Path -LiteralPath $InstallDirectory).Path
$installedScript = Join-Path $resolvedInstallDirectory 'Send-SlaveResult.ps1'
$escapedCanonicalPath = $canonicalScript.Replace("'", "''")

$wrapper = @"
`$ErrorActionPreference = 'Stop'
`$canonicalScript = '$escapedCanonicalPath'

if (-not (Test-Path -LiteralPath `$canonicalScript -PathType Leaf)) {
    throw "BA Planner slave sender is missing: `$canonicalScript"
}

& `$canonicalScript @args
"@

Set-Content -LiteralPath $installedScript -Encoding utf8 -Value $wrapper

$parseErrors = @()
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $installedScript,
    [ref]$null,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "Installed wrapper has PowerShell parse errors: $($parseErrors -join '; ')"
}

Write-Host 'SLAVE_RESULT_SENDER_INSTALLED'
Write-Host "path: $installedScript"
Write-Host ''
Write-Host 'Run after P2 output.md and artifacts are ready:'
Write-Host '& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1"'
