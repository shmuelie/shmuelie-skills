function Get-PackageChannel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BuildReason,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceBranch
    )

    if ($BuildReason -eq 'PullRequest') {
        return 'PullRequest'
    }

    if ($SourceBranch -eq 'refs/heads/main') {
        return 'Stable'
    }

    return 'Preview'
}

function New-PackageVersionSuffix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Stable', 'PullRequest', 'Preview')]
        [string]$Channel,

        [long]$BuildId
    )

    if ($Channel -eq 'Stable') {
        return ''
    }

    if ($BuildId -lt 1) {
        throw 'BuildId must be a positive integer for nonstable packages.'
    }

    switch ($Channel) {
        'PullRequest' { return "pr$BuildId" }
        'Preview' { return "preview$BuildId" }
    }
}
