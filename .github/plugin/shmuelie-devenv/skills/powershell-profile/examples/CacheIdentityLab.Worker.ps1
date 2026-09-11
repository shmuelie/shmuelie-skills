[CmdletBinding()]
param(
    [ValidateSet('writer', 'hold-lock')]
    [string]$Behavior,

    [Parameter(Mandatory)]
    [string]$CommonPath,

    [Parameter(Mandatory)]
    [string]$ScenarioRoot,

    [Parameter(Mandatory)]
    [string]$IdentityPath,

    [string]$PayloadPath,

    [Parameter(Mandatory)]
    [string]$ReadyPath,

    [Parameter(Mandatory)]
    [string]$AcquiredPath,

    [string]$ReleaseGatePath,

    [Parameter(Mandatory)]
    [string]$ResultPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. $CommonPath

$identity = Get-Content -Path $IdentityPath -Raw | ConvertFrom-Json
$payload = if ($PayloadPath) { Get-Content -Path $PayloadPath -Raw | ConvertFrom-Json } else { $null }
Write-SignalFile -Path $ReadyPath -Content 'ready'

$lock = Enter-IdentityMutex -Name $identity.MutexName -Timeout ([timespan]::FromSeconds(10))
try {
    Write-SignalFile -Path $AcquiredPath -Content 'acquired'
    if ($ReleaseGatePath) {
        $null = Wait-SignalFile -Path $ReleaseGatePath -TimeoutMilliseconds 10000
    }

    $result = switch ($Behavior) {
        'writer' {
            Publish-SyntheticSnapshotUnderLock -Root $ScenarioRoot -Identity $identity -Payload $payload -LockState $lock.LockState
        }
        'hold-lock' {
            [pscustomobject]@{
                Action    = 'released'
                LockState = $lock.LockState
            }
        }
    }

    Write-CompleteUtf8File -Path $ResultPath -Content (ConvertTo-StableJson -InputObject $result)
}
finally {
    try {
        $lock.Mutex.ReleaseMutex()
    }
    finally {
        $lock.Mutex.Dispose()
    }
}
