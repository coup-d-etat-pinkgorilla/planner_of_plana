[CmdletBinding()]
param(
    [string]$RepositoryRoot = '',

    [string]$TaskId = 'ba-planner-v7-p2-planning-screen',

    [string]$TaskDirectory = '',

    [string]$OutboxDirectory = '',

    [string]$PackagePath = '',

    [ValidateRange(1, 65535)]
    [int]$DiscoveryPort = 8766,

    [ValidateRange(1, 20)]
    [int]$DiscoveryAttempts = 5
)

$ErrorActionPreference = 'Stop'

function Get-DirectedBroadcastAddress {
    param(
        [Parameter(Mandatory = $true)][string]$Address,
        [Parameter(Mandatory = $true)][int]$PrefixLength
    )

    $addressBytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
    $broadcastBytes = New-Object byte[] 4
    for ($index = 0; $index -lt 4; $index++) {
        $remainingBits = $PrefixLength - ($index * 8)
        if ($remainingBits -ge 8) {
            $maskByte = 255
        }
        elseif ($remainingBits -le 0) {
            $maskByte = 0
        }
        else {
            $maskByte = 256 - [int][Math]::Pow(2, 8 - $remainingBits)
        }
        $broadcastBytes[$index] = $addressBytes[$index] -bor (255 - $maskByte)
    }
    return ([System.Net.IPAddress]::new($broadcastBytes)).ToString()
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$resolvedRepository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$packageScript = Join-Path $resolvedRepository 'tools\new_cross_pc_handoff.ps1'
$senderScript = Join-Path $resolvedRepository 'tools\send_cross_pc_handoff.ps1'

if (-not (Test-Path -LiteralPath $packageScript -PathType Leaf)) {
    throw "Missing handoff packager: $packageScript"
}
if (-not (Test-Path -LiteralPath $senderScript -PathType Leaf)) {
    throw "Missing handoff sender: $senderScript"
}

if ([string]::IsNullOrWhiteSpace($TaskDirectory)) {
    $TaskDirectory = Join-Path $resolvedRepository 'docs\migration\p2-planning-screen'
}
if ([string]::IsNullOrWhiteSpace($OutboxDirectory)) {
    $OutboxDirectory = Join-Path ([Environment]::GetFolderPath('Desktop')) 'BA-Planner-Handoff-Outbox'
}

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    if (-not (Test-Path -LiteralPath $OutboxDirectory)) {
        New-Item -ItemType Directory -Path $OutboxDirectory | Out-Null
    }
    $existingPackages = @(
        Get-ChildItem -LiteralPath $OutboxDirectory -Filter "$TaskId-*.zip" -File |
            Select-Object -ExpandProperty Name
    )

    & $packageScript `
        -TaskDirectory $TaskDirectory `
        -DestinationDirectory $OutboxDirectory `
        -TaskId $TaskId

    $package = Get-ChildItem -LiteralPath $OutboxDirectory -Filter "$TaskId-*.zip" -File |
        Where-Object { $existingPackages -notcontains $_.Name } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($null -eq $package) {
        throw 'The packager did not create a new handoff ZIP.'
    }
    $PackagePath = $package.FullName
}
else {
    $PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
}

$broadcastTargets = New-Object 'System.Collections.Generic.HashSet[string]'
[void]$broadcastTargets.Add('255.255.255.255')
[void]$broadcastTargets.Add('127.0.0.1')
try {
    foreach ($interfaceAddress in Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop) {
        if ($interfaceAddress.IPAddress -eq '127.0.0.1') {
            continue
        }
        $broadcast = Get-DirectedBroadcastAddress `
            -Address $interfaceAddress.IPAddress `
            -PrefixLength $interfaceAddress.PrefixLength
        [void]$broadcastTargets.Add($broadcast)
    }
}
catch {
    Write-Verbose "Could not enumerate directed broadcasts: $_"
}

$nonce = [guid]::NewGuid().ToString('N')
$requestJson = [ordered]@{
    service = 'BA_PLANNER_HANDOFF_DISCOVERY_V1'
    task_id = $TaskId
    nonce = $nonce
} | ConvertTo-Json -Compress
$requestBytes = [System.Text.Encoding]::UTF8.GetBytes($requestJson)

$udp = New-Object System.Net.Sockets.UdpClient
$udp.EnableBroadcast = $true
$udp.Client.ReceiveTimeout = 1200
try {
    # Windows reports ICMP port-unreachable replies from unrelated broadcast
    # targets as WSAECONNRESET on the next Receive call. Discovery probes many
    # adapters, so suppress that per-target noise and keep waiting for a valid
    # nonce-matched response.
    $sioUdpConnectionReset = -1744830452
    [void]$udp.Client.IOControl(
        $sioUdpConnectionReset,
        [byte[]](0),
        [byte[]](0)
    )
}
catch {
    Write-Verbose "Could not disable UDP connection-reset notifications: $_"
}
$discoveryResponse = $null
$discoveryRemote = $null

try {
    Write-Host "Discovering the BA Planner master receiver on UDP/$DiscoveryPort..."
    for ($attempt = 1; $attempt -le $DiscoveryAttempts -and $null -eq $discoveryResponse; $attempt++) {
        foreach ($target in $broadcastTargets) {
            $endpoint = [System.Net.IPEndPoint]::new(
                [System.Net.IPAddress]::Parse($target),
                $DiscoveryPort
            )
            try {
                [void]$udp.Send($requestBytes, $requestBytes.Length, $endpoint)
            }
            catch [System.Net.Sockets.SocketException] {
                Write-Verbose "Discovery broadcast to $target failed: $_"
            }
        }

        $receiveUntil = [DateTime]::UtcNow.AddMilliseconds(1200)
        while ([DateTime]::UtcNow -lt $receiveUntil -and $null -eq $discoveryResponse) {
            try {
                $remoteEndpoint = [System.Net.IPEndPoint]::new(
                    [System.Net.IPAddress]::Any,
                    0
                )
                $responseBytes = $udp.Receive([ref]$remoteEndpoint)
                $candidate = [System.Text.Encoding]::UTF8.GetString($responseBytes) |
                    ConvertFrom-Json
                if ($candidate.service -ne 'BA_PLANNER_HANDOFF_DISCOVERY_V1') {
                    continue
                }
                if ($candidate.task_id -ne $TaskId -or $candidate.nonce -ne $nonce) {
                    continue
                }
                if ([string]::IsNullOrWhiteSpace([string]$candidate.token)) {
                    continue
                }
                $discoveryResponse = $candidate
                $discoveryRemote = $remoteEndpoint
            }
            catch [System.Net.Sockets.SocketException] {
                $ignorableErrors = @(
                    [System.Net.Sockets.SocketError]::TimedOut,
                    [System.Net.Sockets.SocketError]::ConnectionReset,
                    [System.Net.Sockets.SocketError]::NetworkUnreachable,
                    [System.Net.Sockets.SocketError]::HostUnreachable
                )
                if ($ignorableErrors -notcontains $_.Exception.SocketErrorCode) {
                    throw
                }
                break
            }
        }
    }
}
finally {
    $udp.Dispose()
}

if ($null -eq $discoveryResponse -or $null -eq $discoveryRemote) {
    throw "No BA Planner master receiver was discovered after $DiscoveryAttempts attempts."
}

$masterHost = $discoveryRemote.Address.ToString()
$masterPort = [int]$discoveryResponse.port
Write-Host "Discovered the master receiver at ${masterHost}:$masterPort."
Write-Host 'Sending the four handoff files...'

& $senderScript `
    -PackagePath $PackagePath `
    -MasterHost $masterHost `
    -Port $masterPort `
    -Token ([string]$discoveryResponse.token)

Write-Host ''
Write-Host 'SLAVE_RESULT_SENT_TO_DISCOVERED_MASTER'
Write-Host "package: $PackagePath"
Write-Host "master: ${masterHost}:$masterPort"
Write-Host 'The one-time token was not written to disk or output.'
