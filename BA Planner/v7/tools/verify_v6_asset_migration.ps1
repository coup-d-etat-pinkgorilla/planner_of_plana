param()

$ErrorActionPreference = "Stop"

$projectDirectory = Split-Path -Parent $PSScriptRoot
$uiManifestPath = Join-Path $projectDirectory "docs\migration\v6-asset-backend-connection\ui-assets-v1.manifest.json"
$recognitionRoot = Join-Path $projectDirectory "backend\assets\recognition\v1"
$recognitionManifestPath = Join-Path $recognitionRoot "manifest.json"

function Get-NormalizedPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-ChildPath([string]$Path, [string]$Root) {
    $resolvedPath = Get-NormalizedPath $Path
    $resolvedRoot = (Get-NormalizedPath $Root).TrimEnd("\") + "\"
    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Asset path escapes its root: $resolvedPath"
    }
    return $resolvedPath
}

function Assert-FileHash([string]$Path, [string]$ExpectedHash, [long]$ExpectedBytes) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Asset is missing: $Path"
    }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -ne $ExpectedBytes) {
        throw "Asset size mismatch: $Path"
    }
    $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedHash.ToLowerInvariant()) {
        throw "Asset hash mismatch: $Path"
    }
}

$uiManifest = Get-Content -LiteralPath $uiManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($asset in $uiManifest.assets) {
    $destination = Assert-ChildPath (Join-Path $projectDirectory $asset.destination_path) (Join-Path $projectDirectory "frontend\assets")
    Assert-FileHash $destination $asset.sha256 $asset.bytes

    $source = Get-NormalizedPath (Join-Path $projectDirectory $asset.source_path)
    Assert-FileHash $source $asset.sha256 $asset.bytes
}

$recognitionManifest = Get-Content -LiteralPath $recognitionManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($asset in $recognitionManifest.assets) {
    $destination = Assert-ChildPath (Join-Path $recognitionRoot $asset.path) $recognitionRoot
    Assert-FileHash $destination $asset.sha256 $asset.bytes

    if ($asset.source_path -like "../v6/*") {
        $source = Get-NormalizedPath (Join-Path $projectDirectory $asset.source_path)
        Assert-FileHash $source $asset.sha256 $asset.bytes
    }
}

Write-Host "Verified $($uiManifest.assets.Count) Flutter UI assets and $($recognitionManifest.assets.Count) backend recognition assets."
