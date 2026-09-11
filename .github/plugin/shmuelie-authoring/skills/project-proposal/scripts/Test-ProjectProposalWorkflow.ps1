[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $FixtureRoot
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path $PSScriptRoot -Parent
$newProposal = Join-Path $PSScriptRoot 'New-ProjectProposal.ps1'
$testProposal = Join-Path $PSScriptRoot 'Test-ProjectProposal.ps1'
$runRoot = Join-Path ([IO.Path]::GetFullPath($FixtureRoot)) "project-proposal-tests-$([guid]::NewGuid().ToString('N'))"
$null = New-Item -Path $runRoot -ItemType Directory

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-ThrowsMessage {
    param([scriptblock] $Action, [string] $Pattern, [string] $Case)

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -notmatch $Pattern) {
            throw "Case '$Case' failed with an unexpected error: $($_.Exception.Message)"
        }
        return
    }
    throw "Case '$Case' did not produce the expected error."
}

function Copy-JsonObject {
    param([object] $InputObject)

    $InputObject | ConvertTo-Json -Depth 8 | ConvertFrom-Json
}

$unicodeValue = "A$([char]::ConvertFromUtf32(0x1F600))e$([char]0x0301)"
$brief = [ordered]@{
    projectId = 'fixture-proposal'
    title = 'Fixture Proposal'
    summary = 'A fictional local proposal used to exercise meaningful package behavior.'
    problem = 'Reviewers need a deterministic fixture that does not claim a working product.'
    audience = @('Proposal reviewers')
    verifiedCapabilities = @('The local scaffold can render this explicit synthetic brief.')
    proposals = @('A future concept would present a reviewable offline walkthrough.')
    assumptions = @('Reviewers can read Markdown files locally.')
    openQuestions = @('Which future feasibility experiment should run first?')
    completedWork = @('The synthetic brief was authored for this workflow test.')
    decisions = @(@{
        decision = 'Keep the fixture offline.'
        rationale = 'No portal or hosted service is needed to validate proposal structure.'
    })
    milestones = @(@{
        name = 'Structure review'
        outcome = 'A reviewer can trace classified claims, risks, and proposed outcomes.'
    })
    risks = @(@{
        risk = 'Polished prose could be mistaken for implementation evidence.'
        mitigation = 'Retain explicit proposal and unverified-status language.'
    })
    submission = @{
        body = 'This fictional fixture proposes a future offline walkthrough. It does not claim a prototype, repository, deployment, portal entry, or submission.'
        shortFields = @(
            @{ name = 'UTF-16 sample'; value = $unicodeValue; maxUnits = 5; counting = 'Utf16CodeUnits' }
            @{ name = 'Character sample'; value = $unicodeValue; maxUnits = 4; counting = 'Characters' }
            @{ name = 'Grapheme sample'; value = $unicodeValue; maxUnits = 3; counting = 'Graphemes' }
        )
    }
}
$briefPath = Join-Path $runRoot 'fixture brief.json'
$brief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $briefPath -Encoding utf8

$previewPath = Join-Path $runRoot 'preview target'
$preview = & $newProposal -BriefPath $briefPath -Destination $previewPath -Layout Compact -WhatIf
Assert-True (-not (Test-Path -LiteralPath $previewPath)) 'WhatIf created a destination.'
Assert-True ($preview.PlannedWrites.Count -eq 5) 'WhatIf did not report the directory, identity, and three compact documents.'

$unownedPath = Join-Path $runRoot 'existing unowned directory'
$null = New-Item -Path $unownedPath -ItemType Directory
$sentinelPath = Join-Path $unownedPath 'sentinel.txt'
Set-Content -LiteralPath $sentinelPath -Value 'preserve me' -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $briefPath -Destination $unownedPath -Layout Compact
} 'not an identified project-proposal package' 'unowned destination'
Assert-True ((Get-Content -LiteralPath $sentinelPath -Raw).Trim() -eq 'preserve me') 'Rejected destination content was modified.'

$failurePath = Join-Path $runRoot 'injected failure proposal'
$failureSentinel = Join-Path $runRoot 'failure sentinel.txt'
Set-Content -LiteralPath $failureSentinel -Value 'adjacent content must survive' -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $briefPath -Destination $failurePath -Layout Compact -TestFailAfterFileWrites 1
} 'Injected proposal write failure' 'injected first-create failure'
Assert-True (-not (Test-Path -LiteralPath $failurePath)) 'Failed first creation published a partial destination.'
Assert-True ((Get-Content -LiteralPath $failureSentinel -Raw).Trim() -eq 'adjacent content must survive') 'Failure cleanup changed a pre-existing sibling.'
Assert-True (@(Get-ChildItem -LiteralPath $runRoot -Filter '.injected failure proposal.project-proposal-stage-*').Count -eq 0) 'Owned staging directory was not cleaned after failure.'

$retry = & $newProposal -BriefPath $briefPath -Destination $failurePath -Layout Compact
Assert-True ($retry.Status -eq 'CreatedAndValidated') 'A clean retry after an injected failure did not publish a complete package.'
$failureReadme = Join-Path $failurePath 'README.md'
$failureReadmeHash = (Get-FileHash -LiteralPath $failureReadme -Algorithm SHA256).Hash
$packageSentinel = Join-Path $failurePath 'authored-sentinel.txt'
Set-Content -LiteralPath $packageSentinel -Value 'preserve authored sibling' -Encoding utf8
Remove-Item -LiteralPath (Join-Path $failurePath 'SUBMISSION.md')
$repair = & $newProposal -BriefPath $briefPath -Destination $failurePath -Layout Compact
Assert-True ($repair.Status -eq 'RepairedAndValidated') 'Missing-file repair was not validated.'
Assert-True ($repair.CreatedFiles.Count -eq 1 -and $repair.CreatedFiles[0] -eq 'SUBMISSION.md') 'Repair created more than the missing document.'
Assert-True ((Get-FileHash -LiteralPath $failureReadme -Algorithm SHA256).Hash -eq $failureReadmeHash) 'Repair overwrote an existing authored document.'
Assert-True ((Get-Content -LiteralPath $packageSentinel -Raw).Trim() -eq 'preserve authored sibling') 'Repair changed an unrelated package file.'

$compactPath = Join-Path $runRoot 'compact proposal with spaces'
$compact = & $newProposal -BriefPath $briefPath -Destination $compactPath -Layout Compact
$compactResult = & $testProposal -Path $compactPath
$proposalText = Get-Content -LiteralPath (Join-Path $compactPath 'PROPOSAL.md') -Raw
$submissionText = Get-Content -LiteralPath (Join-Path $compactPath 'SUBMISSION.md') -Raw
Assert-True ($compactResult.StructurallyReady) 'Compact package was not structurally ready.'
Assert-True ($proposalText -match 'future concept would present') 'Compact proposal omitted authored behavior.'
Assert-True ($submissionText -match '5 / 5.+Utf16CodeUnits') 'UTF-16 count was not rendered as 5.'
Assert-True ($submissionText -match '4 / 4.+Characters') 'Unicode scalar count was not rendered as 4.'
Assert-True ($submissionText -match '3 / 3.+Graphemes') 'Grapheme count was not rendered as 3.'

$readmePath = Join-Path $compactPath 'README.md'
$refinement = "`nAuthored refinement: preserve this sentence on rerun.`n"
Add-Content -LiteralPath $readmePath -Value $refinement -Encoding utf8
$beforeHash = (Get-FileHash -LiteralPath $readmePath -Algorithm SHA256).Hash
$rerun = & $newProposal -BriefPath $briefPath -Destination $compactPath -Layout Compact
$afterHash = (Get-FileHash -LiteralPath $readmePath -Algorithm SHA256).Hash
Assert-True ($beforeHash -eq $afterHash) 'Same-identity rerun overwrote an authored refinement.'
Assert-True ($rerun.CreatedFiles.Count -eq 0 -and $rerun.PreservedFiles.Count -eq 3) 'Rerun did not preserve all compact documents.'

$changedBrief = Copy-JsonObject $brief
$changedBrief.summary = 'Changed source text must not silently rewrite an authored package.'
$changedBriefPath = Join-Path $runRoot 'changed brief.json'
$changedBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $changedBriefPath -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $changedBriefPath -Destination $compactPath -Layout Compact
} 'Stale-source conflict.+brief changed' 'changed brief rerun'
Assert-True ((Get-FileHash -LiteralPath $readmePath -Algorithm SHA256).Hash -eq $afterHash) 'Changed-brief conflict modified an authored document.'

$templateCopy = Join-Path $runRoot 'template copy'
Copy-Item -LiteralPath (Join-Path $skillRoot 'templates') -Destination $templateCopy -Recurse
$templatePath = Join-Path $runRoot 'copied-template proposal'
$null = & $newProposal -BriefPath $briefPath -Destination $templatePath -Layout Compact -TemplateSourceRoot $templateCopy
Add-Content -LiteralPath (Join-Path $templateCopy 'compact\README.md.template') -Value "`nTemplate change for stale-source testing.`n" -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $briefPath -Destination $templatePath -Layout Compact -TemplateSourceRoot $templateCopy
} 'Stale-source conflict.+templates changed' 'changed template rerun'

$conflictBrief = Copy-JsonObject $brief
$conflictBrief.projectId = 'different-project'
$conflictBriefPath = Join-Path $runRoot 'conflicting identity.json'
$conflictBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $conflictBriefPath -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $conflictBriefPath -Destination $compactPath -Layout Compact
} 'identity conflict' 'conflicting identity'

$splitPath = Join-Path $runRoot 'split proposal'
$null = & $newProposal -BriefPath $briefPath -Destination $splitPath -Layout Split
$splitResult = & $testProposal -Path $splitPath
$deliveryText = Get-Content -LiteralPath (Join-Path $splitPath 'DELIVERY.md') -Raw
Assert-True ($splitResult.Documents.Count -eq 5) 'Split layout did not contain exactly five documents.'
Assert-True ($deliveryText -match 'Structure review' -and $deliveryText -match 'synthetic brief was authored') 'Split delivery plan lost milestone or completed-work content.'

$splitReadmePath = Join-Path $splitPath 'README.md'
$splitReadme = Get-Content -LiteralPath $splitReadmePath -Raw
$splitReadme = $splitReadme.Replace('[Specification](SPEC.md)', '[Specification][specification]')
$splitReadme += "`n[specification]: SPEC.md#fixture-proposal-specification`n"
$splitReadme += "`n[External reference][external]`n[external]: https://example.com/reference`n"
Set-Content -LiteralPath $splitReadmePath -Value $splitReadme -Encoding utf8
$externalResult = & $testProposal -Path $splitPath
Assert-True ($externalResult.ExternalLinksNotFetched -eq 1) 'External URL was not classified without fetching.'
Assert-True ($externalResult.LocalLinksChecked -eq 4) 'Reference-style local link was not checked.'

$escapePath = Join-Path $runRoot 'traversal proposal'
$null = & $newProposal -BriefPath $briefPath -Destination $escapePath -Layout Compact
Add-Content -LiteralPath (Join-Path $escapePath 'README.md') -Value "`n[Escape](..\outside.md)`n" -Encoding utf8
Assert-ThrowsMessage {
    & $testProposal -Path $escapePath
} 'Local link traversal is not allowed' 'link traversal'

$fragmentPath = Join-Path $runRoot 'broken fragment proposal'
$null = & $newProposal -BriefPath $briefPath -Destination $fragmentPath -Layout Split
Add-Content -LiteralPath (Join-Path $fragmentPath 'README.md') -Value "`n[Missing section](SPEC.md#not-a-heading)`n" -Encoding utf8
Assert-ThrowsMessage {
    & $testProposal -Path $fragmentPath
} 'Broken local fragment' 'broken local fragment'

$absolutePath = Join-Path $runRoot 'absolute link proposal'
$null = & $newProposal -BriefPath $briefPath -Destination $absolutePath -Layout Compact
Add-Content -LiteralPath (Join-Path $absolutePath 'README.md') -Value "`n[Absolute](C:\outside.md)`n" -Encoding utf8
Assert-ThrowsMessage {
    & $testProposal -Path $absolutePath
} 'Unsupported external link scheme|Rooted' 'absolute local path'

$outsideDirectory = Join-Path $runRoot 'outside reparse target'
$null = New-Item -Path $outsideDirectory -ItemType Directory
Set-Content -LiteralPath (Join-Path $outsideDirectory 'outside.md') -Value "# Outside`n`nThis file must not be followed through a reparse point." -Encoding utf8
$reparsePath = Join-Path $runRoot 'reparse proposal'
$null = & $newProposal -BriefPath $briefPath -Destination $reparsePath -Layout Compact
$null = New-Item -Path (Join-Path $reparsePath 'linked') -ItemType Junction -Target $outsideDirectory
Add-Content -LiteralPath (Join-Path $reparsePath 'README.md') -Value "`n[Outside](linked\outside.md)`n" -Encoding utf8
Assert-ThrowsMessage {
    & $testProposal -Path $reparsePath
} 'Reparse-point traversal is not allowed' 'intermediate reparse point'

$unsupportedPath = Join-Path $runRoot 'unsupported link proposal'
$null = & $newProposal -BriefPath $briefPath -Destination $unsupportedPath -Layout Compact
Add-Content -LiteralPath (Join-Path $unsupportedPath 'README.md') -Value "`n[Titled](PROPOSAL.md `"title`")`n" -Encoding utf8
Assert-ThrowsMessage {
    & $testProposal -Path $unsupportedPath
} 'Unsupported Markdown inline link' 'unsupported Markdown link construct'

$overLimitBrief = Copy-JsonObject $brief
$overLimitBrief.projectId = 'over-limit'
$overLimitBrief.submission = @{
    body = $brief.submission.body
    shortFields = @(@{ name = 'Too short'; value = $unicodeValue; maxUnits = 2; counting = 'Graphemes' })
}
$overLimitPath = Join-Path $runRoot 'over limit.json'
$overLimitBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $overLimitPath -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $overLimitPath -Destination (Join-Path $runRoot 'over limit target') -Layout Compact -WhatIf
} 'exceeding its configured limit' 'field limit'

$scalarBrief = Copy-JsonObject $brief
$scalarBrief.projectId = 'scalar-shape'
$scalarBrief.verifiedCapabilities = 'not-an-array'
$scalarBriefPath = Join-Path $runRoot 'scalar shape.json'
$scalarBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $scalarBriefPath -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $scalarBriefPath -Destination (Join-Path $runRoot 'scalar target') -Layout Compact -WhatIf
} "verifiedCapabilities' must be an array" 'scalar classification shape'

$objectBrief = Copy-JsonObject $brief
$objectBrief.projectId = 'object-shape'
$objectBrief.verifiedCapabilities = @(@{ arbitrary = 'object' })
$objectBriefPath = Join-Path $runRoot 'object shape.json'
$objectBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $objectBriefPath -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $objectBriefPath -Destination (Join-Path $runRoot 'object target') -Layout Compact -WhatIf
} 'verifiedCapabilities.+only non-empty strings' 'object classification shape'

$structuredBrief = Copy-JsonObject $brief
$structuredBrief.projectId = 'structured-shape'
$structuredBrief.risks = @{ risk = 'scalar object'; mitigation = 'invalid shape' }
$structuredBriefPath = Join-Path $runRoot 'structured shape.json'
$structuredBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $structuredBriefPath -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $structuredBriefPath -Destination (Join-Path $runRoot 'structured target') -Layout Compact -WhatIf
} "risks' must be an array" 'scalar structured shape'

$emptyBrief = Copy-JsonObject $brief
$emptyBrief.projectId = 'empty-arrays'
foreach ($property in @('audience', 'verifiedCapabilities', 'proposals', 'assumptions', 'openQuestions', 'completedWork', 'decisions', 'milestones', 'risks')) {
    $emptyBrief.$property = @()
}
$emptyBrief.submission = @{ body = $brief.submission.body; shortFields = @() }
$emptyBriefPath = Join-Path $runRoot 'empty arrays.json'
$emptyBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $emptyBriefPath -Encoding utf8
$emptyPath = Join-Path $runRoot 'empty arrays proposal'
$null = & $newProposal -BriefPath $emptyBriefPath -Destination $emptyPath -Layout Compact
$emptyResult = & $testProposal -Path $emptyPath
Assert-True ($emptyResult.StructurallyReady -and $emptyResult.ShortFields.Count -eq 0) 'Valid empty arrays did not produce a structurally valid package.'
Assert-True ((Get-Content -LiteralPath (Join-Path $emptyPath 'PROPOSAL.md') -Raw) -match 'None stated in the brief') 'Empty categories must explicitly state that the brief supplied no entries.'

$upperBrief = Copy-JsonObject $brief
$upperBrief.projectId = 'Uppercase'
$upperPath = Join-Path $runRoot 'uppercase-id.json'
$upperBrief | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $upperPath -Encoding utf8
Assert-ThrowsMessage {
    & $newProposal -BriefPath $upperPath -Destination (Join-Path $runRoot 'uppercase target') -WhatIf
} 'lowercase letters' 'uppercase identity rejected'

$singleHeading = Join-Path $splitPath 'single-heading.md'
Set-Content -LiteralPath $singleHeading -Value "# Scope`n`nAn additional local document." -Encoding utf8
Add-Content -LiteralPath $splitReadmePath -Value "`n[Fragment](single-heading.md#cop)`n" -Encoding utf8
Assert-ThrowsMessage { & $testProposal -Path $splitPath } 'Broken local fragment' 'single heading fragment is not a substring match'

[pscustomobject]@{
    FixtureRoot = $runRoot
    Cases = @(
        'preview-no-write',
        'existing-unowned-destination-preserved',
        'injected-write-failure-cleanup-and-retry',
        'missing-file-no-replace-repair',
        'compact-first-create-with-spaces',
        'rerun-preservation',
        'changed-brief-stale-source-conflict',
        'changed-template-stale-source-conflict',
        'conflicting-identity',
        'split-first-create',
        'reference-links-and-external-no-fetch',
        'local-link-traversal-rejected',
        'broken-fragment-rejected',
        'absolute-path-rejected',
        'intermediate-reparse-rejected',
        'unsupported-link-construct-rejected',
        'utf16-character-grapheme-counts',
        'configured-field-limit-rejected',
        'scalar-array-shape-rejected',
        'object-string-array-shape-rejected',
        'structured-array-shape-rejected',
        'valid-empty-arrays'
        'uppercase-project-id-rejected'
        'single-heading-substring-fragment-rejected'
    )
    CompactDocuments = $compactResult.Documents
    SplitDocuments = $splitResult.Documents
    Counts = $compactResult.ShortFields
    Result = 'Passed'
    Note = 'Structural readiness only; feasibility and implementation were not tested.'
}
