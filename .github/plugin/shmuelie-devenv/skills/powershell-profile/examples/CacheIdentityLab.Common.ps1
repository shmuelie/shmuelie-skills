Set-StrictMode -Version 3.0

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        $null = New-Item -ItemType Directory -Path $Path -Force
    }
}

function Write-CompleteUtf8File {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $directory = Split-Path $Path -Parent
    if ($directory) {
        Ensure-Directory -Path $directory
    }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $stream = [System.IO.FileStream]::new(
        $Path,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )

    try {
        $writer = [System.IO.StreamWriter]::new($stream, $encoding)
        try {
            $writer.Write($Content)
            $writer.Flush()
            $stream.Flush($true)
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function ConvertTo-StableJson {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $InputObject | ConvertTo-Json -Depth 20 -Compress
}

function ConvertTo-IdentityHash {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    [System.Convert]::ToHexString($hash).ToLowerInvariant()
}

function New-OwnedFixtureRoot {
    param(
        [Parameter(Mandatory)]
        [string]$ParentPath,

        [string]$NamePrefix = 'cache-identity-run'
    )

    Ensure-Directory -Path $ParentPath

    $ownerToken = [guid]::NewGuid().ToString('N')
    $rootPath = Join-Path $ParentPath "$NamePrefix-$ownerToken"
    if (Test-Path $rootPath) {
        throw "Refusing to reuse existing fixture root '$rootPath'."
    }

    $null = New-Item -ItemType Directory -Path $rootPath -Force
    $markerPath = Join-Path $rootPath '.fixture-owner.json'
    $marker = [ordered]@{
        ownerToken   = $ownerToken
        createdAtUtc = [datetime]::UtcNow.ToString('o')
    }
    Write-CompleteUtf8File -Path $markerPath -Content (ConvertTo-StableJson -InputObject $marker)

    [pscustomobject]@{
        ParentPath = $ParentPath
        RootPath   = $rootPath
        OwnerToken = $ownerToken
        MarkerPath = $markerPath
    }
}

function Remove-OwnedFixtureRoot {
    param(
        [Parameter(Mandatory)]
        [psobject]$Fixture
    )

    if (-not (Test-Path $Fixture.RootPath)) {
        return
    }
    if (-not (Test-Path $Fixture.MarkerPath)) {
        throw "Refusing to delete '$($Fixture.RootPath)' because the ownership marker is missing."
    }

    $marker = Get-Content -Path $Fixture.MarkerPath -Raw | ConvertFrom-Json
    if ($marker.ownerToken -ne $Fixture.OwnerToken) {
        throw "Refusing to delete '$($Fixture.RootPath)' because the ownership marker does not match this invocation."
    }

    Remove-Item -Path $Fixture.RootPath -Recurse -Force
}

function New-SyntheticLifetimeIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$Scope,

        [Parameter(Mandatory)]
        [int]$ProcessId,

        [Parameter(Mandatory)]
        [datetime]$ProcessStartTimeUtc,

        [Parameter(Mandatory)]
        [string]$LogicalSessionId
    )

    $identityRecord = [ordered]@{
        scope               = $Scope
        processId           = $ProcessId
        processStartTimeUtc = $ProcessStartTimeUtc.ToUniversalTime().ToString('o')
        logicalSessionId    = $LogicalSessionId
    }
    $identityJson = ConvertTo-StableJson -InputObject $identityRecord
    $identityHash = ConvertTo-IdentityHash -Text $identityJson
    $mutexPrefix = if ($IsWindows) { 'Local\CacheIdentityLab-' } else { 'CacheIdentityLab-' }

    [pscustomobject]@{
        Scope               = $identityRecord.scope
        ProcessId           = $identityRecord.processId
        ProcessStartTimeUtc = $identityRecord.processStartTimeUtc
        LogicalSessionId    = $identityRecord.logicalSessionId
        IdentityJson        = $identityJson
        IdentityHash        = $identityHash
        MutexName           = "$mutexPrefix$identityHash"
    }
}

function Get-PublishedSnapshotPath {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [psobject]$Identity
    )

    $publishedRoot = Join-Path $Root 'published'
    Ensure-Directory -Path $publishedRoot
    Join-Path $publishedRoot "$($Identity.IdentityHash).json"
}

function Read-PublishedSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Test-SnapshotIdentity {
    param(
        [Parameter(Mandatory)]
        [psobject]$Snapshot,

        [Parameter(Mandatory)]
        [psobject]$Identity
    )

    $Snapshot.IdentityJson -ceq $Identity.IdentityJson -and
        $Snapshot.IdentityHash -ceq $Identity.IdentityHash
}

function Assert-SnapshotIdentity {
    param(
        [Parameter(Mandatory)]
        [psobject]$Snapshot,

        [Parameter(Mandatory)]
        [psobject]$Identity
    )

    if (-not (Test-SnapshotIdentity -Snapshot $Snapshot -Identity $Identity)) {
        throw 'Refusing to accept a cache hit because the published snapshot identity does not match the requested identity.'
    }
}

function Enter-IdentityMutex {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [timespan]$Timeout
    )

    $mutex = [System.Threading.Mutex]::new($false, $Name)
    $lockState = 'normal'
    $acquired = $false

    try {
        try {
            $acquired = $mutex.WaitOne($Timeout)
        }
        catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
            $lockState = 'abandoned'
        }

        if (-not $acquired) {
            throw [System.TimeoutException]::new("Timed out waiting for lock '$Name'.")
        }

        [pscustomobject]@{
            Mutex     = $mutex
            LockState = $lockState
        }
    }
    catch {
        $mutex.Dispose()
        throw
    }
}

function Publish-SyntheticSnapshotUnderLock {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [psobject]$Identity,

        [Parameter(Mandatory)]
        [psobject]$Payload,

        [Parameter(Mandatory)]
        [string]$LockState
    )

    $publishedPath = Get-PublishedSnapshotPath -Root $Root -Identity $Identity
    $existing = Read-PublishedSnapshot -Path $publishedPath
    if ($null -ne $existing) {
        Assert-SnapshotIdentity -Snapshot $existing -Identity $Identity
    }

    $payloadJson = ConvertTo-StableJson -InputObject $Payload
    $observedPayloadJson = if ($null -ne $existing) { $existing.PayloadJson } else { $null }

    if ($null -ne $existing -and $observedPayloadJson -ceq $payloadJson) {
        return [pscustomobject]@{
            Action              = 'unchanged'
            LockState           = $LockState
            PublishedPath       = $publishedPath
            ObservedPayloadJson = $observedPayloadJson
            ObservedIdentityJson = $existing.IdentityJson
        }
    }

    $snapshot = [ordered]@{
        IdentityJson   = $Identity.IdentityJson
        IdentityHash   = $Identity.IdentityHash
        PayloadJson    = $payloadJson
        Payload        = $Payload
        PublishedAtUtc = [datetime]::UtcNow.ToString('o')
    }
    $snapshotJson = ConvertTo-StableJson -InputObject $snapshot

    $parentPath = Split-Path $publishedPath -Parent
    $tempPath = Join-Path $parentPath ([guid]::NewGuid().ToString('N') + '.tmp')
    $backupPath = $null

    try {
        Write-CompleteUtf8File -Path $tempPath -Content $snapshotJson
        if (Test-Path $publishedPath) {
            $backupPath = Join-Path $parentPath ([guid]::NewGuid().ToString('N') + '.bak')
            [System.IO.File]::Replace($tempPath, $publishedPath, $backupPath)
        }
        else {
            [System.IO.File]::Move($tempPath, $publishedPath)
        }

        [pscustomobject]@{
            Action              = 'published'
            LockState           = $LockState
            PublishedPath       = $publishedPath
            ObservedPayloadJson = $observedPayloadJson
            ObservedIdentityJson = if ($null -ne $existing) { $existing.IdentityJson } else { $null }
        }
    }
    finally {
        if ($tempPath -and (Test-Path $tempPath)) {
            Remove-Item -Path $tempPath -Force
        }
        if ($backupPath -and (Test-Path $backupPath)) {
            Remove-Item -Path $backupPath -Force
        }
    }
}

function Publish-SyntheticSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [psobject]$Identity,

        [Parameter(Mandatory)]
        [psobject]$Payload,

        [timespan]$LockTimeout = [timespan]::FromSeconds(5)
    )

    $lock = Enter-IdentityMutex -Name $Identity.MutexName -Timeout $LockTimeout
    try {
        Publish-SyntheticSnapshotUnderLock -Root $Root -Identity $Identity -Payload $Payload -LockState $lock.LockState
    }
    finally {
        try {
            $lock.Mutex.ReleaseMutex()
        }
        finally {
            $lock.Mutex.Dispose()
        }
    }
}

function Write-SignalFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Content = 'signal'
    )

    $directory = Split-Path $Path -Parent
    Ensure-Directory -Path $directory
    $tempPath = Join-Path $directory ([guid]::NewGuid().ToString('N') + '.signal.tmp')

    try {
        Write-CompleteUtf8File -Path $tempPath -Content $Content
        [System.IO.File]::Move($tempPath, $Path)
    }
    finally {
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Force
        }
    }
}

function Wait-SignalFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateRange(1, 60000)]
        [int]$TimeoutMilliseconds = 5000,

        [psobject]$Child
    )

    $deadline = [datetime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    while ([datetime]::UtcNow -lt $deadline) {
        if (Test-Path $Path) {
            return Get-Content -Path $Path -Raw
        }

        if ($Child -and $Child.Process.HasExited) {
            # The child may have written the signal between the two observations.
            if (Test-Path $Path) { return Get-Content -Path $Path -Raw }
            $diagnostics = Get-ChildDiagnostics -Child $Child
            throw "Child '$($Child.Name)' exited before signal '$Path'. $diagnostics"
        }

        Start-Sleep -Milliseconds 50
    }

    throw "Timed out waiting for signal '$Path'."
}

function Get-ChildDiagnostics {
    param([Parameter(Mandatory)][psobject]$Child)

    if (-not $Child.Process.HasExited) {
        throw "Child '$($Child.Name)' has not exited; output is not final."
    }
    if (-not $Child.StdOutTask.Wait(1000) -or -not $Child.StdErrTask.Wait(1000)) {
        throw "Child '$($Child.Name)' exited with code $($Child.Process.ExitCode), but its output streams did not close."
    }
    "Exit code $($Child.Process.ExitCode). stderr: $($Child.StdErrTask.GetAwaiter().GetResult()) stdout: $($Child.StdOutTask.GetAwaiter().GetResult())"
}

function Remove-FileIfPresent {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force
    }
}
