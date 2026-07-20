$ErrorActionPreference = "Stop"

$frontendDirectory = Split-Path -Parent $PSScriptRoot
$projectDirectory = Split-Path -Parent $frontendDirectory
$launcherSource = Join-Path $frontendDirectory "windows\devtools_launcher\Program.cs"
$debugDestination = Join-Path $projectDirectory "BA Planner v7 DevTools Debug.exe"
$profileDestination = Join-Path $projectDirectory "BA Planner v7 DevTools Profile.exe"
$temporaryLauncher = Join-Path $projectDirectory ".BA Planner v7.devtools-launcher.tmp.exe"

if (-not (Test-Path -LiteralPath $launcherSource)) {
    throw "DevTools launcher source was not found: $launcherSource"
}

if (Test-Path -LiteralPath $temporaryLauncher) {
    Remove-Item -LiteralPath $temporaryLauncher -Force
}

try {
    Add-Type `
        -Path $launcherSource `
        -ReferencedAssemblies @("System.Windows.Forms", "System.Drawing") `
        -OutputAssembly $temporaryLauncher `
        -OutputType WindowsApplication

    Copy-Item -LiteralPath $temporaryLauncher -Destination $debugDestination -Force
    Copy-Item -LiteralPath $temporaryLauncher -Destination $profileDestination -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryLauncher) {
        Remove-Item -LiteralPath $temporaryLauncher -Force
    }
}

Write-Host "Created DevTools Debug launcher: $debugDestination"
Write-Host "Created DevTools Profile launcher: $profileDestination"
