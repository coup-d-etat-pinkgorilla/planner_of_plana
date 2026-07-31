param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$frontendRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$projectRoot = (Resolve-Path (Join-Path $frontendRoot "..")).Path
$buildRoot = Join-Path $frontendRoot "build\windows\x64\runner\Release"
$releaseRoot = Join-Path $projectRoot "release\developer_tools"

if ($CheckOnly) {
    $exe = Join-Path $releaseRoot "ba_planner_v7.exe"
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "Developer tools release is missing: $exe"
    }
    Write-Host "Developer tools release is present: $exe"
    exit 0
}

Push-Location $frontendRoot
try {
    flutter build windows --release -t lib/developer_tools_main.dart
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter developer tools build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$resolvedProject = [IO.Path]::GetFullPath($projectRoot)
$resolvedRelease = [IO.Path]::GetFullPath($releaseRoot)
if (-not $resolvedRelease.StartsWith($resolvedProject + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace release directory outside the project: $resolvedRelease"
}
if (Test-Path -LiteralPath $resolvedRelease) {
    Remove-Item -LiteralPath $resolvedRelease -Recurse -Force
}
New-Item -ItemType Directory -Path $resolvedRelease | Out-Null
Copy-Item -Path (Join-Path $buildRoot "*") -Destination $resolvedRelease -Recurse -Force
Write-Host "Developer tools release built at $resolvedRelease"
