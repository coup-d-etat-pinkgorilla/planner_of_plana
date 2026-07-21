[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,

    [string]$ExpectedSha256 = '',

    [string]$StagingRoot = ''
)

$ErrorActionPreference = 'Stop'

$resolvedPackage = (Resolve-Path -LiteralPath $PackagePath).Path
$packageItem = Get-Item -LiteralPath $resolvedPackage
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPackage).Hash.ToLowerInvariant()

if ([string]::IsNullOrWhiteSpace($ExpectedSha256)) {
    $sidecarPath = [System.IO.Path]::ChangeExtension($resolvedPackage, '.sha256')
    if (-not (Test-Path -LiteralPath $sidecarPath -PathType Leaf)) {
        throw 'ExpectedSha256 was not supplied and the .sha256 sidecar is missing.'
    }
    $ExpectedSha256 = ((Get-Content -LiteralPath $sidecarPath -Raw).Trim() -split '\s+')[0]
}

if ($actualHash -ne $ExpectedSha256.Trim().ToLowerInvariant()) {
    throw "Package SHA-256 mismatch. Expected $ExpectedSha256 but got $actualHash"
}

if ([string]::IsNullOrWhiteSpace($StagingRoot)) {
    $StagingRoot = Join-Path (Split-Path -Parent $resolvedPackage) 'staging'
}
if (-not (Test-Path -LiteralPath $StagingRoot)) {
    New-Item -ItemType Directory -Path $StagingRoot | Out-Null
}
$resolvedStagingRoot = (Resolve-Path -LiteralPath $StagingRoot).Path
$extractDirectory = Join-Path $resolvedStagingRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $extractDirectory | Out-Null
Expand-Archive -LiteralPath $resolvedPackage -DestinationPath $extractDirectory

$outputPath = Join-Path $extractDirectory 'output.md'
$artifactsPath = Join-Path $extractDirectory 'artifacts'
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Package has no output.md: $extractDirectory"
}
if (-not (Test-Path -LiteralPath $artifactsPath -PathType Container)) {
    throw "Package has no artifacts directory: $extractDirectory"
}

$artifactInventory = Get-ChildItem -LiteralPath $artifactsPath -File -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring($extractDirectory.Length).TrimStart([char[]]'\/')
    [pscustomobject]@{
        RelativePath = $relativePath
        Size = $_.Length
        Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
}

[pscustomobject]@{
    Package = $resolvedPackage
    PackageSize = $packageItem.Length
    PackageSha256 = $actualHash
    ExtractedTo = $extractDirectory
    OutputMd = $outputPath
    ArtifactCount = @($artifactInventory).Count
}
$artifactInventory | Format-Table -AutoSize

Write-Host ''
Write-Host 'Inspection only: no patch was applied and no repository file was overwritten.'
