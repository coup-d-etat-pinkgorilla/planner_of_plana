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
P2 슬레이브 결과 인계 패키지를 검증하고 인수하십시오.

- 작업 ID: `$TaskId`
- 패키지 파일: `$($packageItem.Name)`
- 패키지 크기: `$($packageItem.Length)` bytes
- 패키지 SHA-256: `$packageHash`
- manifest: `$(Split-Path -Leaf $manifestPath)`

이 패키지는 다른 PC에서 전달되었습니다. 다음 순서로 처리하십시오.

1. 패키지가 위치한 마스터 PC의 실제 절대경로를 확인하십시오.
2. ZIP 크기와 SHA-256을 위 값 및 manifest와 직접 대조하십시오.
3. 저장소에 바로 덮어쓰지 말고 고유한 staging 디렉터리에 압축을 푸십시오.
4. output.md를 읽고 artifacts 아래 모든 파일의 존재 여부, 0보다 큰 크기와
   output.md에 기록된 SHA-256을 직접 확인하십시오.
5. p2-planning-screen.patch와 현재 작업 트리의 diff를 검토하십시오. 기존 사용자
   변경과 겹치면 적용을 중단하고 충돌 내용을 보고하십시오.
6. git apply --check를 먼저 실행하고 성공한 경우에만 패치를 적용하십시오.
7. Python test, flutter analyze, flutter test, Windows release build,
   codealmanac validate와 git diff --check를 직접 실행하십시오.
8. P2 불변식과 실제 Python backend 및 MockAppService 흐름을 검증하십시오.
9. 검증 중에는 P2 상태를 '검증 중'으로, 모든 조건을 직접 확인한 뒤에만 '완료'로
   almanac/workflows/p0-p6-workflow-status.md를 갱신하십시오.

파일 누락이나 해시 불일치가 있으면 결과물을 직접 재생성하지 말고 기존 슬레이브에게
동일 결과물의 재인계를 요청하십시오.
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
