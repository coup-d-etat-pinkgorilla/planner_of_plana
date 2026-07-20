param(
    [string]$FlutterCommand = "",
    [switch]$Force,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$frontendDirectory = Split-Path -Parent $PSScriptRoot
$projectDirectory = Split-Path -Parent $frontendDirectory
$bundleSource = Join-Path $frontendDirectory "build\windows\x64\runner\Release"
$bundleDestination = Join-Path $projectDirectory "release"
$releaseExecutable = Join-Path $bundleDestination "ba_planner_v7.exe"
$stampName = ".ba_planner_build.json"
$stampPath = Join-Path $bundleDestination $stampName

function Get-NormalizedPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Assert-ProjectChildDirectory([string]$Path, [string]$ExpectedLeafPrefix) {
    $resolvedProject = Get-NormalizedPath $projectDirectory
    $resolvedPath = Get-NormalizedPath $Path
    $parent = Get-NormalizedPath (Split-Path -Parent $resolvedPath)
    $leaf = Split-Path -Leaf $resolvedPath

    if ($parent -ne $resolvedProject -or -not $leaf.StartsWith($ExpectedLeafPrefix)) {
        throw "Refusing to modify an unexpected generated directory: $resolvedPath"
    }
}

function Remove-GeneratedDirectory([string]$Path, [string]$ExpectedLeafPrefix) {
    Assert-ProjectChildDirectory $Path $ExpectedLeafPrefix
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Get-TrackedSourceFiles {
    $sourceTargets = @(
        (Join-Path $frontendDirectory "lib"),
        (Join-Path $frontendDirectory "assets"),
        (Join-Path $frontendDirectory "windows\runner"),
        (Join-Path $frontendDirectory "windows\CMakeLists.txt"),
        (Join-Path $frontendDirectory "pubspec.yaml"),
        (Join-Path $frontendDirectory "pubspec.lock")
    )

    $files = foreach ($target in $sourceTargets) {
        if (-not (Test-Path -LiteralPath $target)) {
            continue
        }

        $item = Get-Item -LiteralPath $target
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $target -File -Recurse
        }
        else {
            $item
        }
    }

    return $files | Sort-Object FullName -Unique
}

function Get-SourceFingerprint {
    $lines = foreach ($file in Get-TrackedSourceFiles) {
        $relativePath = $file.FullName.Substring($frontendDirectory.Length + 1).Replace("\", "/").ToLowerInvariant()
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        "$relativePath|$hash"
    }

    $payload = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($payload))).Replace("-", "")
    }
    finally {
        $sha256.Dispose()
    }
}

function Resolve-FlutterCommand {
    if ($FlutterCommand) {
        if (Test-Path -LiteralPath $FlutterCommand) {
            return (Get-Item -LiteralPath $FlutterCommand).FullName
        }

        $explicitCommand = Get-Command $FlutterCommand -ErrorAction SilentlyContinue
        if ($explicitCommand) {
            return $explicitCommand.Source
        }

        throw "Flutter command was not found: $FlutterCommand"
    }

    $candidates = @()
    if ($env:FLUTTER_ROOT) {
        $candidates += (Join-Path $env:FLUTTER_ROOT "bin\flutter.bat")
    }
    $candidates += "C:\src\flutter\bin\flutter.bat"

    $pathCommand = Get-Command "flutter" -ErrorAction SilentlyContinue
    if ($pathCommand) {
        return $pathCommand.Source
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }

    throw "Flutter SDK를 찾지 못했습니다. FLUTTER_ROOT를 설정하거나 -FlutterCommand를 지정해 주세요."
}

Assert-ProjectChildDirectory $bundleDestination "release"

$fingerprint = Get-SourceFingerprint
$recordedFingerprint = $null
if (Test-Path -LiteralPath $stampPath) {
    try {
        $stamp = Get-Content -LiteralPath $stampPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $recordedFingerprint = $stamp.sourceFingerprint
    }
    catch {
        $recordedFingerprint = $null
    }
}

$isCurrent =
    (Test-Path -LiteralPath $releaseExecutable) -and
    ($recordedFingerprint -eq $fingerprint)

if ($isCurrent -and -not $Force) {
    Write-Host "Release bundle is up to date."
    exit 0
}

if ($CheckOnly) {
    throw "Release bundle is stale. Run frontend\tool\build_windows_release.ps1 or launch BA Planner v7.exe."
}

if (Test-Path -LiteralPath $releaseExecutable) {
    $runningRelease = Get-Process -Name "ba_planner_v7" -ErrorAction SilentlyContinue |
        Where-Object {
            try {
                (Get-NormalizedPath $_.Path) -eq (Get-NormalizedPath $releaseExecutable)
            }
            catch {
                $false
            }
        }
    if ($runningRelease) {
        throw "실행 중인 BA Planner v7을 닫은 뒤 다시 실행해 주세요. Release 파일을 갱신할 수 없습니다."
    }
}

$resolvedFlutterCommand = Resolve-FlutterCommand
Write-Host "Source changes detected. Building the Windows release..."

Push-Location $frontendDirectory
try {
    & $resolvedFlutterCommand build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows release build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath (Join-Path $bundleSource "ba_planner_v7.exe"))) {
    throw "Release bundle was not created at $bundleSource."
}

$stageDirectory = Join-Path $projectDirectory (".release-staging-" + [Guid]::NewGuid().ToString("N"))
$backupDirectory = Join-Path $projectDirectory (".release-backup-" + [Guid]::NewGuid().ToString("N"))
Assert-ProjectChildDirectory $stageDirectory ".release-staging-"
Assert-ProjectChildDirectory $backupDirectory ".release-backup-"

try {
    Copy-Item -LiteralPath $bundleSource -Destination $stageDirectory -Recurse

    $builtAtUtc = [DateTime]::UtcNow
    $stagedExecutable = Join-Path $stageDirectory "ba_planner_v7.exe"
    (Get-Item -LiteralPath $stagedExecutable).LastWriteTimeUtc = $builtAtUtc

    $stampData = [ordered]@{
        schemaVersion = 1
        sourceFingerprint = $fingerprint
        builtAtUtc = $builtAtUtc.ToString("o")
        flutterCommand = $resolvedFlutterCommand
    }
    $stampData | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stageDirectory $stampName) -Encoding UTF8

    if (Test-Path -LiteralPath $bundleDestination) {
        Move-Item -LiteralPath $bundleDestination -Destination $backupDirectory
    }

    try {
        Move-Item -LiteralPath $stageDirectory -Destination $bundleDestination
    }
    catch {
        if (Test-Path -LiteralPath $backupDirectory) {
            Move-Item -LiteralPath $backupDirectory -Destination $bundleDestination
        }
        throw
    }

    Remove-GeneratedDirectory $backupDirectory ".release-backup-"

    $launcherPath = Join-Path $projectDirectory "BA Planner v7.exe"
    if (Test-Path -LiteralPath $launcherPath) {
        try {
            (Get-Item -LiteralPath $launcherPath).LastWriteTimeUtc = $builtAtUtc
        }
        catch {
            Write-Warning "Release is current, but the launcher timestamp could not be updated: $($_.Exception.Message)"
        }
    }
}
finally {
    Remove-GeneratedDirectory $stageDirectory ".release-staging-"
}

Write-Host "Release bundle synchronized: $bundleDestination"
