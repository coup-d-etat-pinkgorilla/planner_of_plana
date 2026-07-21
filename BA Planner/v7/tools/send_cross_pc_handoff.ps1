[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,

    [Parameter(Mandatory = $true)]
    [string]$MasterHost,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [Parameter(Mandatory = $true)]
    [string]$Token
)

$ErrorActionPreference = 'Stop'

$resolvedPackage = (Resolve-Path -LiteralPath $PackagePath).Path
if ([System.IO.Path]::GetExtension($resolvedPackage) -ne '.zip') {
    throw 'PackagePath must point to the handoff ZIP.'
}

$basePath = [System.IO.Path]::Combine(
    [System.IO.Path]::GetDirectoryName($resolvedPackage),
    [System.IO.Path]::GetFileNameWithoutExtension($resolvedPackage)
)
$files = @(
    $resolvedPackage,
    "$basePath.sha256",
    "$basePath.manifest.json",
    "$basePath-MASTER_PROMPT.md"
)

foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Missing wireless transfer file: $file"
    }
    if ((Get-Item -LiteralPath $file).Length -le 0) {
        throw "Wireless transfer file is empty: $file"
    }
}

$uri = "http://${MasterHost}:$Port/upload"
$headers = @{ Authorization = "Bearer $Token" }

foreach ($file in $files) {
    $headers['X-File-Name'] = Split-Path -Leaf $file
    Write-Host "Sending $($headers['X-File-Name'])"
    $response = Invoke-WebRequest `
        -Uri $uri `
        -Method Put `
        -InFile $file `
        -Headers $headers `
        -ContentType 'application/octet-stream' `
        -UseBasicParsing
    Write-Host $response.Content
}

Write-Host ''
Write-Host 'WIRELESS_HANDOFF_SENT'
Write-Host "package: $resolvedPackage"
Write-Host "master: ${MasterHost}:$Port"
