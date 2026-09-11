[CmdletBinding()]
param(
    [string]$FixtureParent = (Join-Path $HOME '.cache-identity-lab'),

    [switch]$KeepFixture
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Disposable teaching lab for lifetime-qualified cache identity and atomic
# snapshot publication. APIs used here are documented by Microsoft:
# https://learn.microsoft.com/dotnet/api/system.threading.mutex
# https://learn.microsoft.com/dotnet/api/system.io.file.replace
# https://learn.microsoft.com/dotnet/api/system.diagnostics.process.kill

$commonPath = Join-Path $PSScriptRoot 'CacheIdentityLab.Common.ps1'
$workerPath = Join-Path $PSScriptRoot 'CacheIdentityLab.Worker.ps1'
. $commonPath

function Start-OwnedChild {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$OwnedChildren,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command pwsh -CommandType Application -All -ErrorAction Stop |
        Select-Object -First 1).Source
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Failed to start child '$Name'." }
    }
    catch {
        $process.Dispose()
        throw
    }
    $child = [pscustomobject]@{
        Name = $Name
        Process = $process
        StdOutTask = $null
        StdErrTask = $null
        WasExited = $false
    }
    $OwnedChildren.Add($child)
    $child.StdOutTask = $process.StandardOutput.ReadToEndAsync()
    $child.StdErrTask = $process.StandardError.ReadToEndAsync()
    $child
}

function New-ScenarioRoot {
    param(
        [Parameter(Mandatory)]
        [string]$LabRoot,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $path = Join-Path $LabRoot $Name
    Ensure-Directory -Path $path
    $path
}

function Start-OwnedWorkerProcess {
    param(
        [ValidateNotNull()]
        [System.Collections.Generic.List[object]]$OwnedChildren,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Behavior,

        [Parameter(Mandatory)]
        [string]$ScenarioRoot,

        [Parameter(Mandatory)]
        [psobject]$Identity,

        [psobject]$Payload,

        [string]$ReleaseGatePath
    )

    Ensure-Directory -Path $ScenarioRoot

    $readyPath = Join-Path $ScenarioRoot "$Name.ready"
    $acquiredPath = Join-Path $ScenarioRoot "$Name.acquired"
    $resultPath = Join-Path $ScenarioRoot "$Name.result.json"
    $identityPath = Join-Path $ScenarioRoot "$Name.identity.json"
    $payloadPath = if ($Payload) { Join-Path $ScenarioRoot "$Name.payload.json" } else { $null }
    $stdoutPath = Join-Path $ScenarioRoot "$Name.stdout.log"
    $stderrPath = Join-Path $ScenarioRoot "$Name.stderr.log"

    foreach ($path in @($readyPath, $acquiredPath, $resultPath, $identityPath, $payloadPath, $stdoutPath, $stderrPath)) {
        if (-not $path) { continue }
        Remove-FileIfPresent -Path $path
    }
    Write-CompleteUtf8File -Path $identityPath -Content (ConvertTo-StableJson -InputObject $Identity)
    if ($Payload) {
        Write-CompleteUtf8File -Path $payloadPath -Content (ConvertTo-StableJson -InputObject $Payload)
    }

    $arguments = @(
        '-NoProfile',
        '-File', $workerPath,
        '-Behavior', $Behavior,
        '-CommonPath', $commonPath,
        '-ScenarioRoot', $ScenarioRoot,
        '-IdentityPath', $identityPath,
        '-ReadyPath', $readyPath,
        '-AcquiredPath', $acquiredPath,
        '-ResultPath', $resultPath
    )
    if ($payloadPath) {
        $arguments += @('-PayloadPath', $payloadPath)
    }
    if ($ReleaseGatePath) {
        $arguments += @('-ReleaseGatePath', $ReleaseGatePath)
    }

    $child = Start-OwnedChild -OwnedChildren $OwnedChildren -Name $Name -Arguments $arguments
    $child | Add-Member -NotePropertyMembers @{
        ScenarioRoot  = $ScenarioRoot
        ReadyPath     = $readyPath
        AcquiredPath  = $acquiredPath
        ReleaseGate   = $ReleaseGatePath
        ResultPath    = $resultPath
        StdOutPath    = $stdoutPath
        StdErrPath    = $stderrPath
    }
    $child
}

function Wait-OwnedWorkerProcess {
    param(
        [Parameter(Mandatory)]
        [psobject]$Child,

        [ValidateRange(1, 60000)]
        [int]$TimeoutMilliseconds = 10000
    )

    if (-not $Child.Process.WaitForExit($TimeoutMilliseconds)) {
        throw "Timed out waiting for child '$($Child.Name)' to exit."
    }

    if ($Child.Process.ExitCode -ne 0) {
        throw "Child '$($Child.Name)' failed. $(Get-ChildDiagnostics -Child $Child)"
    }

    if (-not (Test-Path $Child.ResultPath)) {
        throw "Child '$($Child.Name)' exited successfully but did not produce '$($Child.ResultPath)'."
    }

    Get-Content -Path $Child.ResultPath -Raw | ConvertFrom-Json
}

function Stop-OwnedChildren {
    param(
        [ValidateNotNull()]
        [System.Collections.Generic.List[object]]$OwnedChildren
    )

    $failures = [System.Collections.Generic.List[System.Exception]]::new()
    foreach ($child in $OwnedChildren) {
        if ($null -eq $child.Process -or $child.WasExited) {
            continue
        }

        try {
            if (-not $child.Process.HasExited) {
                try { Stop-Process -Id $child.Process.Id -Force -ErrorAction Stop }
                catch {
                    if (-not $child.Process.HasExited) { throw }
                }
                if (-not $child.Process.WaitForExit(3000)) {
                    throw "Child '$($child.Name)' did not exit after termination."
                }
            }
            $child.WasExited = $child.Process.HasExited
            if (-not $child.WasExited) { throw "Child '$($child.Name)' exit is unconfirmed." }
        }
        catch {
            $failures.Add([System.InvalidOperationException]::new(
                "Cleanup failed for '$($child.Name)': $($_.Exception.Message)", $_.Exception))
        }
        finally {
            if ($child.WasExited) {
                try { $child.Process.Dispose() }
                catch { $failures.Add($_.Exception) }
            }
        }
    }
    if ($failures.Count) {
        throw [System.AggregateException]::new(
            'Owned-child cleanup was incomplete; preserve fixtures for diagnosis.', $failures)
    }
}

function Start-InterruptedOwnerProcess {
    param(
        [ValidateNotNull()]
        [System.Collections.Generic.List[object]]$OwnedChildren,

        [Parameter(Mandatory)]
        [string]$ScenarioRoot,

        [Parameter(Mandatory)]
        [psobject]$Identity
    )

    $scriptPath = Join-Path $ScenarioRoot 'owned-interrupted-owner.ps1'
    $acquiredPath = Join-Path $ScenarioRoot 'interrupted-owner.acquired'
    $partialPath = Join-Path $ScenarioRoot 'interrupted-owner.partial'
    $identityPath = Join-Path $ScenarioRoot 'interrupted-owner.identity.json'
    $stdoutPath = Join-Path $ScenarioRoot 'interrupted-owner.stdout.log'
    $stderrPath = Join-Path $ScenarioRoot 'interrupted-owner.stderr.log'

    foreach ($path in @($scriptPath, $acquiredPath, $partialPath, $identityPath, $stdoutPath, $stderrPath)) {
        Remove-FileIfPresent -Path $path
    }
    Write-CompleteUtf8File -Path $identityPath -Content (ConvertTo-StableJson -InputObject $Identity)

    $scriptContent = @'
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. '__COMMON__'
$identity = Get-Content -Path '__IDENTITY__' -Raw | ConvertFrom-Json
$publishedPath = Get-PublishedSnapshotPath -Root '__SCENARIO__' -Identity $identity
$lock = Enter-IdentityMutex -Name $identity.MutexName -Timeout ([timespan]::FromSeconds(10))
Write-SignalFile -Path '__ACQUIRED__' -Content 'acquired'
$partialTempPath = Join-Path (Split-Path $publishedPath -Parent) 'interrupted-owner.partial.tmp'
[System.IO.File]::WriteAllText($partialTempPath, '{"partial":true', [System.Text.UTF8Encoding]::new($false))
Write-SignalFile -Path '__PARTIAL__' -Content $partialTempPath
[System.Diagnostics.Process]::GetCurrentProcess().Kill()
'@
    $scriptContent = $scriptContent.Replace('__COMMON__', ($commonPath -replace "'", "''"))
    $scriptContent = $scriptContent.Replace('__IDENTITY__', ($identityPath -replace "'", "''"))
    $scriptContent = $scriptContent.Replace('__SCENARIO__', ($ScenarioRoot -replace "'", "''"))
    $scriptContent = $scriptContent.Replace('__ACQUIRED__', ($acquiredPath -replace "'", "''"))
    $scriptContent = $scriptContent.Replace('__PARTIAL__', ($partialPath -replace "'", "''"))
    Write-CompleteUtf8File -Path $scriptPath -Content $scriptContent

    $child = Start-OwnedChild -OwnedChildren $OwnedChildren -Name 'interrupted-owner' -Arguments @('-NoProfile', '-File', $scriptPath)
    $child | Add-Member -NotePropertyMembers @{
        ScenarioRoot = $ScenarioRoot
        AcquiredPath = $acquiredPath
        PartialPath  = $partialPath
        ScriptPath   = $scriptPath
        StdOutPath   = $stdoutPath
        StdErrPath   = $stderrPath
    }
    $child
}

function Invoke-NestedFailureCleanupCheck {
    param(
        [Parameter(Mandatory)]
        [string]$LabRoot,

        [Parameter(Mandatory)]
        [string]$RunScope,

        [Parameter(Mandatory)][AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$OwnedChildren
    )

    $nestedFixture = New-OwnedFixtureRoot -ParentPath $LabRoot -NamePrefix 'cleanup-check'

    try {
        $identity = New-SyntheticLifetimeIdentity -Scope "$RunScope/cleanup-check" -ProcessId 9300 -ProcessStartTimeUtc ([datetime]'2026-09-10T20:00:00Z') -LogicalSessionId 'cleanup-check'
        $releaseGatePath = Join-Path $nestedFixture.RootPath 'hold.release'
        $child = Start-OwnedWorkerProcess -OwnedChildren $OwnedChildren -Name 'cleanup-holder' -Behavior 'hold-lock' -ScenarioRoot $nestedFixture.RootPath -Identity $identity -ReleaseGatePath $releaseGatePath
        $null = Wait-SignalFile -Path $child.ReadyPath -Child $child -TimeoutMilliseconds 10000
        $null = Wait-SignalFile -Path $child.AcquiredPath -Child $child -TimeoutMilliseconds 10000
        throw 'Simulated failure path after child acquisition.'
    }
    catch {
        if ($_.Exception.Message -ne 'Simulated failure path after child acquisition.') { throw }
    }
    finally {
        Stop-OwnedChildren -OwnedChildren $OwnedChildren
        Remove-OwnedFixtureRoot -Fixture $nestedFixture
    }
    Assert-True -Condition (-not (Test-Path $nestedFixture.RootPath)) -Message 'Nested failure cleanup should remove only the owned child fixture.'
    Assert-True -Condition $child.WasExited -Message 'Nested failure cleanup should stop only the owned child process.'
    return [pscustomobject]@{
        Scenario        = 'failure-cleanup'
        ExpectedOutcome = 'Owned child processes are stopped and only the owned child fixture is removed on failure.'
        ChildExited     = $child.WasExited
        FixtureRemoved  = (-not (Test-Path $nestedFixture.RootPath))
    }
}

Ensure-Directory -Path $FixtureParent
$sentinelPath = Join-Path $FixtureParent 'preserve-me.sentinel'
if (-not (Test-Path $sentinelPath)) {
    Write-CompleteUtf8File -Path $sentinelPath -Content 'This file proves cleanup is limited to owned child fixtures.'
}
$sentinelContent = Get-Content -Path $sentinelPath -Raw

$labFixture = New-OwnedFixtureRoot -ParentPath $FixtureParent -NamePrefix 'cache-identity-lab'
$ownedChildren = [System.Collections.Generic.List[object]]::new()
$scenarios = [System.Collections.Generic.List[object]]::new()
$runScope = "cache-identity-lab/$($labFixture.OwnerToken)"
$errorToThrow = $null
$cleanupSummary = $null

try {
    $restartRoot = New-ScenarioRoot -LabRoot $labFixture.RootPath -Name 'restart-and-session-reuse'
    $naiveRoot = Join-Path $restartRoot 'naive'
    Ensure-Directory -Path $naiveRoot
    $naivePath = Join-Path $naiveRoot 'session-reused.json'
    Write-CompleteUtf8File -Path $naivePath -Content '{"publishedBy":"old-process"}'

    $restartOld = New-SyntheticLifetimeIdentity -Scope "$runScope/restart" -ProcessId 4242 -ProcessStartTimeUtc ([datetime]'2026-09-10T16:00:00Z') -LogicalSessionId 'session-reused'
    $restartNew = New-SyntheticLifetimeIdentity -Scope "$runScope/restart" -ProcessId 4242 -ProcessStartTimeUtc ([datetime]'2026-09-10T16:05:00Z') -LogicalSessionId 'session-reused'
    $oldPublish = Publish-SyntheticSnapshot -Root $restartRoot -Identity $restartOld -Payload ([pscustomobject]@{ Writer = 'old-process'; Attempt = 1 })
    $newPublish = Publish-SyntheticSnapshot -Root $restartRoot -Identity $restartNew -Payload ([pscustomobject]@{ Writer = 'new-process'; Attempt = 1 })
    Assert-True -Condition (Test-Path $naivePath) -Message 'Session-only cache storage should still collide on restart.'
    Assert-True -Condition ($restartOld.IdentityHash -ne $restartNew.IdentityHash) -Message 'Restarted process must get a new lifetime-qualified identity.'
    Assert-True -Condition ($oldPublish.PublishedPath -ne $newPublish.PublishedPath) -Message 'Restarted process should publish to a different lifetime-qualified snapshot.'
    $scenarios.Add([pscustomobject]@{
            Scenario        = 'restart-and-session-reuse'
            ExpectedOutcome = 'A session-only key collides, while the lifetime-qualified identity publishes a new first snapshot after restart.'
        })

    $pidReuseA = New-SyntheticLifetimeIdentity -Scope "$runScope/pid-reuse" -ProcessId 7000 -ProcessStartTimeUtc ([datetime]'2026-09-10T17:00:00Z') -LogicalSessionId 'session-pid-reuse'
    $pidReuseB = New-SyntheticLifetimeIdentity -Scope "$runScope/pid-reuse" -ProcessId 7000 -ProcessStartTimeUtc ([datetime]'2026-09-10T18:00:00Z') -LogicalSessionId 'session-pid-reuse'
    Assert-True -Condition ($pidReuseA.IdentityHash -ne $pidReuseB.IdentityHash) -Message 'PID reuse must still produce a new identity when start time changes.'
    $scenarios.Add([pscustomobject]@{
            Scenario        = 'pid-reuse'
            ExpectedOutcome = 'Same PID plus a different start time maps to a different cache file and the same-hash lock name.'
        })

    $caseIdentity = New-SyntheticLifetimeIdentity -Scope "$runScope/case" -ProcessId 8000 -ProcessStartTimeUtc ([datetime]'2026-09-10T18:00:00Z') -LogicalSessionId 'CaseSensitive'
    $mutated = [pscustomobject]@{
        IdentityJson = $caseIdentity.IdentityJson.Replace('CaseSensitive', 'casesensitive')
        IdentityHash = $caseIdentity.IdentityHash
    }
    Assert-True -Condition (-not (Test-SnapshotIdentity -Snapshot $mutated -Identity $caseIdentity)) -Message 'A case-only serialized identity change must be rejected.'
    $caseRoot = New-ScenarioRoot -LabRoot $labFixture.RootPath -Name 'case-sensitive-payload'
    $null = Publish-SyntheticSnapshot -Root $caseRoot -Identity $caseIdentity -Payload ([pscustomobject]@{ Value = 'A' })
    $changedCase = Publish-SyntheticSnapshot -Root $caseRoot -Identity $caseIdentity -Payload ([pscustomobject]@{ Value = 'a' })
    Assert-True -Condition ($changedCase.Action -eq 'published') -Message 'Case-only payload changes must not be suppressed.'
    $scenarios.Add([pscustomobject]@{
        Scenario = 'case-sensitive-comparison'
        ExpectedOutcome = 'Identity mutations are rejected and case-only payload updates publish.'
    })

    $concurrentRoot = New-ScenarioRoot -LabRoot $labFixture.RootPath -Name 'concurrent-writers'
    $concurrentIdentity = New-SyntheticLifetimeIdentity -Scope "$runScope/concurrent" -ProcessId 9001 -ProcessStartTimeUtc ([datetime]'2026-09-10T19:00:00Z') -LogicalSessionId 'session-concurrent'
    $firstPayload = [pscustomobject]@{ Writer = 'writer-1'; Attempt = 1 }
    $secondPayload = [pscustomobject]@{ Writer = 'writer-2'; Attempt = 2 }
    $releaseWriter1 = Join-Path $concurrentRoot 'writer-1.release'

    $writer1 = Start-OwnedWorkerProcess -OwnedChildren $ownedChildren -Name 'writer-1' -Behavior 'writer' -ScenarioRoot $concurrentRoot -Identity $concurrentIdentity -Payload $firstPayload -ReleaseGatePath $releaseWriter1
    $null = Wait-SignalFile -Path $writer1.ReadyPath -Child $writer1 -TimeoutMilliseconds 10000
    $null = Wait-SignalFile -Path $writer1.AcquiredPath -Child $writer1 -TimeoutMilliseconds 10000

    $writer2 = Start-OwnedWorkerProcess -OwnedChildren $ownedChildren -Name 'writer-2' -Behavior 'writer' -ScenarioRoot $concurrentRoot -Identity $concurrentIdentity -Payload $secondPayload
    $null = Wait-SignalFile -Path $writer2.ReadyPath -Child $writer2 -TimeoutMilliseconds 10000

    Write-SignalFile -Path $releaseWriter1 -Content 'release'
    $writer1Result = Wait-OwnedWorkerProcess -Child $writer1 -TimeoutMilliseconds 10000
    $writer2Result = Wait-OwnedWorkerProcess -Child $writer2 -TimeoutMilliseconds 10000
    $concurrentPublished = Read-PublishedSnapshot -Path (Get-PublishedSnapshotPath -Root $concurrentRoot -Identity $concurrentIdentity)
    Assert-True -Condition ($writer1Result.Action -eq 'published') -Message 'Writer 1 should publish after the release handshake.'
    Assert-True -Condition ($writer2Result.ObservedPayloadJson -eq (ConvertTo-StableJson -InputObject $firstPayload)) -Message 'Writer 2 should reread writer 1''s published snapshot before deciding to overwrite it.'
    Assert-True -Condition ($concurrentPublished.Payload.Writer -eq 'writer-2') -Message 'Writer 2 should publish the final complete document.'
    Assert-SnapshotIdentity -Snapshot $concurrentPublished -Identity $concurrentIdentity
    $scenarios.Add([pscustomobject]@{
            Scenario        = 'concurrent-writers'
            ExpectedOutcome = 'Writer 1 acquires first, writer 2 waits, rereads writer 1''s snapshot, and the final file stays a complete JSON document.'
        })

    $timeoutRoot = New-ScenarioRoot -LabRoot $labFixture.RootPath -Name 'lock-timeout'
    $timeoutIdentity = New-SyntheticLifetimeIdentity -Scope "$runScope/timeout" -ProcessId 9002 -ProcessStartTimeUtc ([datetime]'2026-09-10T19:10:00Z') -LogicalSessionId 'session-timeout'
    $timeoutReleaseGate = Join-Path $timeoutRoot 'timeout.release'
    $timeoutHolder = Start-OwnedWorkerProcess -OwnedChildren $ownedChildren -Name 'timeout-holder' -Behavior 'hold-lock' -ScenarioRoot $timeoutRoot -Identity $timeoutIdentity -ReleaseGatePath $timeoutReleaseGate
    $null = Wait-SignalFile -Path $timeoutHolder.ReadyPath -Child $timeoutHolder -TimeoutMilliseconds 10000
    $null = Wait-SignalFile -Path $timeoutHolder.AcquiredPath -Child $timeoutHolder -TimeoutMilliseconds 10000

    $timedOut = $false
    try {
        $null = Publish-SyntheticSnapshot -Root $timeoutRoot -Identity $timeoutIdentity -Payload ([pscustomobject]@{ Writer = 'after-timeout'; Attempt = 1 }) -LockTimeout ([timespan]::FromMilliseconds(150))
    }
    catch [System.TimeoutException] {
        $timedOut = $true
    }
    Assert-True -Condition $timedOut -Message 'Timeout should prove only that the acquisition deadline expired.'
    Write-SignalFile -Path $timeoutReleaseGate -Content 'release'
    $null = Wait-OwnedWorkerProcess -Child $timeoutHolder -TimeoutMilliseconds 10000
    $retryPublish = Publish-SyntheticSnapshot -Root $timeoutRoot -Identity $timeoutIdentity -Payload ([pscustomobject]@{ Writer = 'retry-success'; Attempt = 2 })
    Assert-True -Condition ($retryPublish.Action -eq 'published') -Message 'Retry should succeed once the holder releases the lock.'
    $scenarios.Add([pscustomobject]@{
            Scenario        = 'lock-timeout'
            ExpectedOutcome = 'The acquisition deadline expires while the lock is held; after release, a retry succeeds.'
        })

    $interruptedRoot = New-ScenarioRoot -LabRoot $labFixture.RootPath -Name 'interrupted-write'
    $interruptedIdentity = New-SyntheticLifetimeIdentity -Scope "$runScope/interrupted" -ProcessId 9003 -ProcessStartTimeUtc ([datetime]'2026-09-10T19:20:00Z') -LogicalSessionId 'session-abandoned'
    $baseline = Publish-SyntheticSnapshot -Root $interruptedRoot -Identity $interruptedIdentity -Payload ([pscustomobject]@{ Writer = 'baseline'; Attempt = 0 })
    $observer = [System.Threading.Mutex]::new($false, $interruptedIdentity.MutexName)
    try {
        $interruptedOwner = Start-InterruptedOwnerProcess -OwnedChildren $ownedChildren -ScenarioRoot $interruptedRoot -Identity $interruptedIdentity
        $null = Wait-SignalFile -Path $interruptedOwner.AcquiredPath -Child $interruptedOwner -TimeoutMilliseconds 10000
        $partialTempPath = Wait-SignalFile -Path $interruptedOwner.PartialPath -Child $interruptedOwner -TimeoutMilliseconds 10000
        $null = $interruptedOwner.Process.WaitForExit(5000)
        Assert-True -Condition ($interruptedOwner.Process.HasExited) -Message 'Interrupted owner should terminate before recovery.'

        $publishedAfterCrash = Read-PublishedSnapshot -Path $baseline.PublishedPath
        Assert-True -Condition ($publishedAfterCrash.Payload.Writer -eq 'baseline') -Message 'Interrupted publication must not replace the last published snapshot.'
        Assert-True -Condition (Test-Path $partialTempPath) -Message 'Interrupted owner should leave a partial temp artifact for cleanup.'

        $recovery = Publish-SyntheticSnapshot -Root $interruptedRoot -Identity $interruptedIdentity -Payload ([pscustomobject]@{ Writer = 'recovered'; Attempt = 1 })
        $publishedAfterRecovery = Read-PublishedSnapshot -Path $baseline.PublishedPath
        Assert-True -Condition ($recovery.LockState -eq 'abandoned') -Message 'With an observer handle keeping the kernel object alive, the recovery acquire should surface abandonment.'
        Assert-True -Condition ($publishedAfterRecovery.Payload.Writer -eq 'recovered') -Message 'Recovery publish should write the new complete snapshot.'
        Assert-SnapshotIdentity -Snapshot $publishedAfterRecovery -Identity $interruptedIdentity
        Remove-FileIfPresent -Path $partialTempPath
        $scenarios.Add([pscustomobject]@{
                Scenario        = 'interrupted-write-and-abandonment'
                ExpectedOutcome = 'The last published snapshot survives the crash, recovery reacquires an abandoned mutex because an observer handle kept the kernel object alive, and the reread/republish path remains mandatory.'
            })
    }
    finally {
        $observer.Dispose()
    }

    $scenarios.Add((Invoke-NestedFailureCleanupCheck -LabRoot $labFixture.RootPath -RunScope $runScope -OwnedChildren $ownedChildren))
}
catch {
    $errorToThrow = $_
}
finally {
    try {
        Stop-OwnedChildren -OwnedChildren $ownedChildren
    }
    catch {
        if ($errorToThrow) {
            throw [System.AggregateException]::new(
                "Lab failed and cleanup was incomplete. Fixture retained: $($labFixture.RootPath)",
                [System.Exception[]]@($errorToThrow.Exception, $_.Exception))
        }
        throw
    }
    $sentinelStillPresent = Test-Path $sentinelPath
    $sentinelUnchanged = $sentinelStillPresent -and ((Get-Content -Path $sentinelPath -Raw) -ceq $sentinelContent)

    if (-not $KeepFixture) {
        Remove-OwnedFixtureRoot -Fixture $labFixture
    }

    $cleanupSummary = [pscustomobject]@{
        SentinelPath                = $sentinelPath
        SentinelStillPresent        = $sentinelStillPresent
        SentinelUnchanged           = $sentinelUnchanged
        OwnedFixtureRemoved         = if ($KeepFixture) { $false } else { -not (Test-Path $labFixture.RootPath) }
        PreservedOwnedFixturePath   = if ($KeepFixture) { $labFixture.RootPath } else { $null }
        CurrentOwnedFixturePresent  = Test-Path $labFixture.RootPath
    }
}

Assert-True -Condition $cleanupSummary.SentinelStillPresent -Message 'Cleanup must preserve pre-existing files in the caller-selected parent.'
Assert-True -Condition $cleanupSummary.SentinelUnchanged -Message 'Cleanup must not rewrite the preserved sentinel.'
if (-not $KeepFixture) {
    Assert-True -Condition $cleanupSummary.OwnedFixtureRemoved -Message 'Cleanup must remove only the owned child fixture created by this invocation.'
    Assert-True -Condition (-not $cleanupSummary.CurrentOwnedFixturePresent) -Message 'The owned child fixture created by this invocation should not remain after cleanup.'
}

if ($errorToThrow) {
    throw $errorToThrow
}

[pscustomobject]@{
    FixtureParent = $FixtureParent
    Cleanup       = $cleanupSummary
    Scenarios     = $scenarios
}
