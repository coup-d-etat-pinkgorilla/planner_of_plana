[CmdletBinding()]
param(
    [string]$RepositoryRoot = 'C:\Users\brigh\planner_of_plana\BA Planner\v7',

    [string]$TaskId = 'ba-planner-v7-p2-planning-screen',

    [ValidateRange(1, 65535)]
    [int]$Port = 8765,

    [string]$InboxDirectory = '',

    [switch]$InspectExisting,

    [string]$PackagePath = ''
)

$ErrorActionPreference = 'Stop'

$resolvedRepository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$receiverScript = Join-Path $resolvedRepository 'tools\receive_cross_pc_handoff.py'
$inspectorScript = Join-Path $resolvedRepository 'tools\inspect_cross_pc_handoff.ps1'

if (-not (Test-Path -LiteralPath $receiverScript -PathType Leaf)) {
    throw "Missing receiver engine: $receiverScript"
}
if (-not (Test-Path -LiteralPath $inspectorScript -PathType Leaf)) {
    throw "Missing handoff inspector: $inspectorScript"
}

if ([string]::IsNullOrWhiteSpace($InboxDirectory)) {
    $InboxDirectory = Join-Path $resolvedRepository "docs\migration\handoffs\incoming\$TaskId"
}
if (-not (Test-Path -LiteralPath $InboxDirectory)) {
    New-Item -ItemType Directory -Path $InboxDirectory | Out-Null
}
$resolvedInbox = (Resolve-Path -LiteralPath $InboxDirectory).Path

$masterPrompt = $null
$package = $null

if ($InspectExisting) {
    if ([string]::IsNullOrWhiteSpace($PackagePath)) {
        $package = Get-ChildItem -LiteralPath $resolvedInbox -Filter '*.zip' -File |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($null -eq $package) {
            throw "No handoff ZIP exists in $resolvedInbox"
        }
    }
    else {
        $package = Get-Item -LiteralPath (Resolve-Path -LiteralPath $PackagePath).Path
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($package.Name)
    $promptPath = Join-Path $package.DirectoryName "$baseName-MASTER_PROMPT.md"
    if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
        throw "The matching master prompt is missing: $promptPath"
    }
    $masterPrompt = Get-Item -LiteralPath $promptPath
}
else {
    $existingPromptNames = @(
        Get-ChildItem -LiteralPath $resolvedInbox -Filter '*-MASTER_PROMPT.md' -File |
            Select-Object -ExpandProperty Name
    )

    Write-Host 'Starting the one-time BA Planner slave-result receiver.'
    Write-Host 'Give the printed upload_url, port and token to the slave PC.'
    Write-Host 'Allow Windows Firewall access only on a trusted private network.'
    Write-Host ''

    & py -3.11 $receiverScript `
        --destination $resolvedInbox `
        --task-id $TaskId `
        --port $Port

    if ($LASTEXITCODE -ne 0) {
        throw "The slave-result receiver exited with code $LASTEXITCODE"
    }

    $masterPrompt = Get-ChildItem -LiteralPath $resolvedInbox -Filter '*-MASTER_PROMPT.md' -File |
        Where-Object { $existingPromptNames -notcontains $_.Name } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $masterPrompt) {
        throw 'The receiver stopped without creating a new MASTER_PROMPT.md file.'
    }

    $baseName = $masterPrompt.Name.Substring(
        0,
        $masterPrompt.Name.Length - '-MASTER_PROMPT.md'.Length
    )
    $packagePathFromPrompt = Join-Path $resolvedInbox "$baseName.zip"
    if (-not (Test-Path -LiteralPath $packagePathFromPrompt -PathType Leaf)) {
        throw "The ZIP matching the received master prompt is missing: $packagePathFromPrompt"
    }
    $package = Get-Item -LiteralPath $packagePathFromPrompt
}

Write-Host ''
Write-Host 'Inspecting the received package before exposing its prompt...'
& $inspectorScript -PackagePath $package.FullName

$promptText = Get-Content -LiteralPath $masterPrompt.FullName -Raw -Encoding utf8
if ([string]::IsNullOrWhiteSpace($promptText)) {
    throw "The received master prompt is empty: $($masterPrompt.FullName)"
}
$promptText | Set-Clipboard

Write-Host ''
Write-Host 'SLAVE_RESULT_READY_FOR_MASTER'
Write-Host "package: $($package.FullName)"
Write-Host "master_prompt: $($masterPrompt.FullName)"
Write-Host 'clipboard: COPIED'
Write-Host ''
Write-Host 'Open the existing master Codex task and press Ctrl+V.'
