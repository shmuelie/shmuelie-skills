[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$fixture = Join-Path $PSScriptRoot 'synthetic.tm7'
$hash = (Get-FileHash -LiteralPath $fixture).Hash
$result = & (Join-Path $PSScriptRoot 'Read-SyntheticModel.ps1') -Path $fixture
if ($result.SourceHash -cne $hash -or (Get-FileHash -LiteralPath $fixture).Hash -cne $hash) { throw 'Source hash changed.' }
if ($result.Diagrams.Count -ne 2 -or $result.Threats.Count -ne 2) { throw 'Collection traversal mismatch.' }
if (-not $result.Threats[0].RelationshipResolved -or $result.Threats[1].RelationshipResolved) { throw 'Diagram-scoped reference resolution failed.' }
if ($result.Threats[1].State -cne 'Unknown') { throw 'Missing state not preserved.' }
foreach ($kind in @('MissingName','UnresolvedEndpoint','UnresolvedThreatFlow','MissingState')) {
    if (@($result.IntegrityProblems | Where-Object Kind -CEQ $kind).Count -ne 1) { throw "Expected one $kind." }
}
if ($result.CategoryCounts.Count -ne 2 -or $result.StateCounts.Count -ne 2) { throw 'Summary distribution mismatch.' }
if ($result.Inferences.Count -or $result.Recommendations.Count) { throw 'Extractor invented analysis.' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('synthetic-model-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $scratch
try {
    $text = [IO.File]::ReadAllText($fixture)
    $cases = @(
        @{Text=$text.Replace('Synthetic-TM7-1','Unknown');Expected='Unsupported input'},
        @{Text=$text.Replace('anyType','DifferentProperty');Expected='Unsupported property collection'},
        @{Text=$text.Replace('DrawingSurfaceModel','DifferentDiagram');Expected='Unsupported drawing surface'},
        @{Text=$text.Replace('<Guid>diagram-b</Guid>','<Guid>diagram-a</Guid>');Expected='duplicate diagram ID'},
        @{Text=$text.Replace('<?xml version="1.0" encoding="utf-8"?>','<!DOCTYPE ThreatModel [<!ENTITY example "blocked">]>');Expected='DTD'}
    )
    foreach ($case in $cases) {
        $path = Join-Path $scratch 'rejected.tm7'
        [IO.File]::WriteAllText($path, $case.Text)
        $failure = $null
        try { & (Join-Path $PSScriptRoot 'Read-SyntheticModel.ps1') -Path $path | Out-Null }
        catch { $failure = $_ }
        if (-not $failure -or $failure.Exception.Message -notmatch $case.Expected) {
            throw "Expected rejection '$($case.Expected)', got '$failure'."
        }
    }
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
$result | ConvertTo-Json -Depth 8
Write-Output 'Synthetic dictionary traversal and integrity cases passed; source bytes unchanged.'
