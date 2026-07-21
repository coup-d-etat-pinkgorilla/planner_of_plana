[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$TaskId
)

$ErrorActionPreference = 'Stop'

$resolvedTaskDirectory = (Resolve-Path -LiteralPath $TaskDirectory).Path
$outputPath = Join-Path $resolvedTaskDirectory 'output.md'
$artifactsPath = Join-Path $resolvedTaskDirectory 'artifacts'

if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Missing output.md: $outputPath"
}
if ((Get-Item -LiteralPath $outputPath).Length -le 0) {
    throw "output.md is empty: $outputPath"
}
if (-not (Test-Path -LiteralPath $artifactsPath -PathType Container)) {
    throw "Missing artifacts directory: $artifactsPath"
}

$artifactFiles = @(Get-ChildItem -LiteralPath $artifactsPath -File -Recurse)
if ($artifactFiles.Count -eq 0) {
    throw "The artifacts directory contains no files: $artifactsPath"
}
$emptyArtifacts = @($artifactFiles | Where-Object Length -LE 0)
if ($emptyArtifacts.Count -gt 0) {
    throw "Artifacts must be non-empty: $($emptyArtifacts.FullName -join ', ')"
}

if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
    New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
}
$resolvedDestination = (Resolve-Path -LiteralPath $DestinationDirectory).Path

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$baseName = "$TaskId-$timestamp"
$packagePath = Join-Path $resolvedDestination "$baseName.zip"
$hashPath = Join-Path $resolvedDestination "$baseName.sha256"
$manifestPath = Join-Path $resolvedDestination "$baseName.manifest.json"
$masterPromptPath = Join-Path $resolvedDestination "$baseName-MASTER_PROMPT.md"

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ba-planner-handoff-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

try {
    Copy-Item -LiteralPath $outputPath -Destination (Join-Path $temporaryRoot 'output.md')
    Copy-Item -LiteralPath $artifactsPath -Destination (Join-Path $temporaryRoot 'artifacts') -Recurse

    Compress-Archive -LiteralPath @(
        (Join-Path $temporaryRoot 'output.md'),
        (Join-Path $temporaryRoot 'artifacts')
    ) -DestinationPath $packagePath

    $packageItem = Get-Item -LiteralPath $packagePath
    $packageHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $packagePath).Hash.ToLowerInvariant()
    Set-Content -LiteralPath $hashPath -Encoding utf8 -Value "$packageHash  $($packageItem.Name)"

    $manifest = [ordered]@{
        task_id = $TaskId
        package = $packageItem.Name
        package_size = $packageItem.Length
        package_sha256 = $packageHash
        artifact_count = $artifactFiles.Count
        created_at = (Get-Date).ToString('o')
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8

    $masterPrompt = @"
Validate and accept the BA Planner v7 P2 slave-result handoff package.

- Task ID: $TaskId
- Package file: $($packageItem.Name)
- Package size: $($packageItem.Length) bytes
- Package SHA-256: $packageHash
- Manifest: $(Split-Path -Leaf $manifestPath)

This package was transferred from another PC. Perform these steps in order:

1. Resolve the package's actual absolute path on the master PC.
2. Independently compare the ZIP size and SHA-256 with the values above and the manifest.
3. Extract only into a unique staging directory; do not overwrite the repository directly.
4. Read output.md. Verify that every reported artifact exists, is non-empty, and matches
   the size and SHA-256 recorded in output.md.
5. Review p2-planning-screen.patch and the current worktree diff. Stop and report any
   overlap with pre-existing user changes.
6. Run git apply --check first. Apply the patch only if the check succeeds and the scope
   is correct.
7. Independently run the Python tests, flutter analyze, flutter test, Windows release
   build, codealmanac validate, and git diff --check.
8. Verify the P2 invariants and both the real Python backend and MockAppService flows.
9. Record P2 as 'verifying' while checking. Mark it complete in
   almanac/workflows/p0-p6-workflow-status.md only after every completion condition has
   been independently confirmed.

For a wireless transfer, first confirm WIRELESS_HANDOFF_RECEIVED and its ZIP verification
output. Wireless delivery transports files but does not replace any validation step.

If a file is missing or a hash differs, do not recreate the result. Request re-delivery
of the same existing artifact from the slave.
"@
    Set-Content -LiteralPath $masterPromptPath -Encoding utf8 -Value $masterPrompt

    [pscustomobject]@{
        TaskId = $TaskId
        Package = $packagePath
        PackageSize = $packageItem.Length
        PackageSha256 = $packageHash
        HashFile = $hashPath
        Manifest = $manifestPath
        MasterPrompt = $masterPromptPath
    } | Format-List
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
