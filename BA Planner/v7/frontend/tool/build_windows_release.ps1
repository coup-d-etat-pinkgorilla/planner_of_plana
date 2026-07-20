param(
    [string]$FlutterCommand = ""
)

$ErrorActionPreference = "Stop"

$frontendDirectory = Split-Path -Parent $PSScriptRoot
$projectDirectory = Split-Path -Parent $frontendDirectory
$syncScript = Join-Path $PSScriptRoot "sync_windows_release.ps1"
$launcherSource = Join-Path $frontendDirectory "windows\release_launcher\Program.cs"
$launcherDestination = Join-Path $projectDirectory "BA Planner v7.exe"
$temporaryLauncher = Join-Path $projectDirectory ".BA Planner v7.launcher.tmp.exe"

$syncArguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $syncScript, "-Force")
if ($FlutterCommand) {
    $syncArguments += @("-FlutterCommand", $FlutterCommand)
}

& powershell.exe @syncArguments
if ($LASTEXITCODE -ne 0) {
    throw "Release synchronization failed with exit code $LASTEXITCODE."
}

if (Test-Path -LiteralPath $temporaryLauncher) {
    Remove-Item -LiteralPath $temporaryLauncher -Force
}

try {
    Add-Type `
        -Path $launcherSource `
        -ReferencedAssemblies "System.Windows.Forms" `
        -OutputAssembly $temporaryLauncher `
        -OutputType WindowsApplication

    Move-Item -LiteralPath $temporaryLauncher -Destination $launcherDestination -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryLauncher) {
        Remove-Item -LiteralPath $temporaryLauncher -Force
    }
}

Write-Host "Created self-synchronizing launcher: $launcherDestination"
Write-Host "Created runtime bundle: $(Join-Path $projectDirectory 'release')"
