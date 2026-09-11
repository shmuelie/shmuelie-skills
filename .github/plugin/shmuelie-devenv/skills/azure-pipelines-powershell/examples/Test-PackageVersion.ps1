[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'PackageVersion.ps1')

function Assert-Equal {
    param(
        [AllowNull()]
        [object]$Actual,

        [AllowNull()]
        [object]$Expected,

        [Parameter(Mandatory)]
        [string]$Case
    )

    if ($Actual -ne $Expected) {
        throw "$Case`: expected '$Expected', got '$Actual'."
    }
}

function Assert-Throws {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [Parameter(Mandatory)]
        [string]$Case,

        [Parameter(Mandatory)]
        [string]$ExpectedMessage
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -cne $ExpectedMessage) { throw }
        return
    }

    throw "$Case`: expected an exception."
}

$cases = @(
    @{
        Actual = Get-PackageChannel -BuildReason PullRequest -SourceBranch refs/pull/73/merge
        Expected = 'PullRequest'
        Case = 'PR merge ref remains a PR channel'
    },
    @{
        Actual = Get-PackageChannel -BuildReason Manual -SourceBranch refs/heads/main
        Expected = 'Stable'
        Case = 'Direct main run is stable'
    },
    @{
        Actual = Get-PackageChannel -BuildReason IndividualCI -SourceBranch refs/heads/users/alex/work
        Expected = 'Preview'
        Case = 'Feature branch CI is preview'
    },
    @{
        Actual = New-PackageVersionSuffix -Channel Stable
        Expected = ''
        Case = 'Stable package has no suffix'
    },
    @{
        Actual = New-PackageVersionSuffix -Channel PullRequest -BuildId 42
        Expected = 'pr42'
        Case = 'PR suffix is deterministic'
    },
    @{
        Actual = New-PackageVersionSuffix -Channel Preview -BuildId 7
        Expected = 'preview7'
        Case = 'Preview suffix is deterministic'
    }
)

foreach ($case in $cases) {
    Assert-Equal @case
}

Assert-Throws -Case 'Nonstable build requires a positive ID' -ExpectedMessage 'BuildId must be a positive integer for nonstable packages.' -Action {
    New-PackageVersionSuffix -Channel Preview -BuildId 0
}

Write-Host "Passed $($cases.Count + 1) no-network package version cases."
