#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ScratchRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$templates = Join-Path $PSScriptRoot '..\templates'
. (Join-Path $templates 'Release.Common.ps1')
$planWrapper = Join-Path $templates 'New-ReleasePlan.ps1'
$publishWrapper = Join-Path $templates 'Publish-Release.ps1'
$scratch = Get-Item -LiteralPath $ScratchRoot
if (-not $scratch.PSIsContainer -or ($scratch.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'ScratchRoot must be an existing non-link directory.'
}
$work = [IO.Directory]::CreateDirectory((Join-Path $scratch.FullName ('release-tests-' + [guid]::NewGuid().ToString('N')))).FullName
$cases = [Collections.Generic.List[object]]::new()
$sha = '0123456789abcdef0123456789abcdef01234567'
$steps = @('Preflight', 'CreateDraft', 'UploadAssets', 'VerifyAssets', 'PushPackage', 'PushSymbols', 'PublishRelease', 'VerifyRelease')
$contextNames = @('GITHUB_REPOSITORY', 'RELEASE_REPOSITORY', 'GITHUB_SHA', 'GITHUB_EVENT_NAME', 'GITHUB_REF', 'NUGET_API_KEY')

function Assert-Equal {
    param([AllowNull()]$Expected, [AllowNull()]$Actual)
    if ($null -eq $Expected) {
        if ($null -ne $Actual) { throw "Assertion: expected null, got '$Actual'." }
        return
    }
    if ($null -eq $Actual -or $Expected.GetType() -ne $Actual.GetType() -or $Expected -cne $Actual) {
        throw "Assertion: expected '$Expected' [$($Expected.GetType().Name)], got '$Actual'."
    }
}

function Assert-Sequence {
    param([AllowEmptyCollection()][object[]]$Expected, [AllowEmptyCollection()][object[]]$Actual)
    Assert-Equal -Expected $Expected.Count -Actual $Actual.Count
    for ($i = 0; $i -lt $Expected.Count; $i++) { Assert-Equal -Expected $Expected[$i] -Actual $Actual[$i] }
}

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$Message,
        [type]$ExceptionType,
        [string]$Category,
        [string]$ErrorId
    )
    $caught = $null
    try { $null = & $Action } catch { $caught = $_ }
    if ($null -eq $caught) { throw 'Assertion: expected an exception, action returned normally.' }
    if ($PSBoundParameters.ContainsKey('Message')) { Assert-Equal -Expected $Message -Actual $caught.Exception.Message }
    if ($PSBoundParameters.ContainsKey('Category')) {
        Assert-Equal -Expected $Category -Actual $caught.CategoryInfo.Category.ToString()
    }
    if ($PSBoundParameters.ContainsKey('ErrorId')) {
        Assert-Equal -Expected $ErrorId -Actual $caught.FullyQualifiedErrorId
    }
    if ($PSBoundParameters.ContainsKey('ExceptionType')) {
        $exception = $caught.Exception
        # PowerShell wraps .NET method invocations; inspect only those known wrappers.
        while ($exception.GetType() -ne $ExceptionType -and
            $exception -is [Management.Automation.RuntimeException] -and $null -ne $exception.InnerException) {
            $exception = $exception.InnerException
        }
        Assert-Equal -Expected $ExceptionType.FullName -Actual $exception.GetType().FullName
    }
}

function Add-Case {
    param([string]$Name, [scriptblock]$Action, $Data = $null)
    if (@($cases | Where-Object Name -ceq $Name).Count) { throw "Duplicate case: $Name" }
    $cases.Add([pscustomobject]@{ Name = $Name; Action = $Action; Data = $Data })
}

function New-OwnedDirectory {
    [IO.Directory]::CreateDirectory((Join-Path $work ([guid]::NewGuid().ToString('N')))).FullName
}

function Get-Hash {
    param([string]$Path)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path))).ToLowerInvariant()
}

function Write-Zip {
    param([string]$Path, [System.Collections.IDictionary]$Entries)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($name in $Entries.Keys) {
                $entryStream = $zip.CreateEntry($name).Open()
                try {
                    $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Entries[$name])
                    $entryStream.Write($bytes, 0, $bytes.Length)
                } finally { $entryStream.Dispose() }
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
}

function New-Nuspec {
    param(
        [AllowEmptyString()][string]$Id = 'Owner.Library',
        [AllowEmptyString()][string]$Version = '1.2.3',
        [AllowEmptyString()][string]$Commit = $sha,
        [string]$Omit = '',
        [switch]$Namespace
    )
    $ns = if ($Namespace) { ' xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd"' } else { '' }
    $idNode = if ($Omit -ne 'id') { '<id>' + [Security.SecurityElement]::Escape($Id) + '</id>' } else { '' }
    $versionNode = if ($Omit -ne 'version') { '<version>' + [Security.SecurityElement]::Escape($Version) + '</version>' } else { '' }
    $attribute = if ($Omit -ne 'commit') { ' commit="' + [Security.SecurityElement]::Escape($Commit) + '"' } else { '' }
    $repoNode = if ($Omit -ne 'repository') { '<repository type="git" url="https://github.com/owner/library"' + $attribute + '/>' } else { '' }
    "<package$ns><metadata>$idNode$versionNode$repoNode</metadata></package>"
}

function Write-Package {
    param([string]$Path, [string]$Xml, [string]$Pdb = '', [string]$NuspecName = 'Owner.Library.nuspec')
    $entries = [ordered]@{}
    $entries[$NuspecName] = $Xml
    $entries['README.md'] = 'Tiny offline fixture; not a distributable library.'
    if ($Pdb) { $entries[$Pdb] = 'test-owned pdb marker' }
    Write-Zip $Path $entries
}

function New-Fixture {
    param([string]$Version = '1.2.3', [string]$Id = 'Owner.Library', [string]$Repository = 'owner/library', [switch]$Wildcard)
    $root = New-OwnedDirectory
    $directory = [IO.Directory]::CreateDirectory((Join-Path $root $(if ($Wildcard) { 'artifacts[1]' } else { 'artifacts' }))).FullName
    $xml = New-Nuspec -Id $Id -Version $Version -Namespace
    $names = @("$Id.$Version.nupkg", "$Id.$Version.snupkg")
    Write-Package (Join-Path $directory $names[0]) $xml
    Write-Package (Join-Path $directory $names[1]) $xml 'lib/net10.0/Owner.Library.pdb'
    $notes = "### Fixed`n- Preserve signed integer bounds."
    $changelog = "# Changes`n`n## [9.0.0] - 2026-10-01`nNot this section.`n`n## [$Version] - 2024-02-29`n`n$notes`n`n## [0.0.1] - 2020-01-01`nNot these notes."
    $parameters = @{
        Repository = $Repository; EventName = 'push'; Ref = "refs/tags/v$Version"; Commit = $sha
        ProjectVersion = $Version; PackageId = $Id; Changelog = $changelog; ArtifactDirectory = $directory
    }
    $plan = New-LibraryReleasePlan @parameters
    $project = Join-Path $root 'Library.csproj'
    [IO.File]::WriteAllText($project, '<Project><PropertyGroup><PackageVersion>99.0.0</PackageVersion><PackageId>Literal.Wrong</PackageId></PropertyGroup></Project>')
    $changelogPath = Join-Path $root 'CHANGELOG.md'
    [IO.File]::WriteAllText($changelogPath, $changelog)
    [pscustomobject]@{
        Root = $root; Directory = $directory; Names = $names; Notes = $notes; Parameters = $parameters
        Plan = $plan; Project = $project; ChangelogPath = $changelogPath
    }
}

function Assert-Plan {
    param($Plan, $Fixture)
    Assert-Equal -Expected 1 -Actual $Plan.SchemaVersion
    foreach ($pair in @(
        @('Repository', $Fixture.Parameters.Repository), @('Tag', $Fixture.Parameters.Ref.Substring(10)),
        @('Version', $Fixture.Parameters.ProjectVersion), @('Commit', $sha), @('PackageId', $Fixture.Parameters.PackageId),
        @('Notes', $Fixture.Notes)
    )) { Assert-Equal -Expected $pair[1] -Actual $Plan.($pair[0]) }
    Assert-Equal -Expected ($Fixture.Parameters.ProjectVersion.Contains('-')) -Actual $Plan.Prerelease
    Assert-Equal -Expected 2 -Actual @($Plan.Artifacts).Count
    Assert-Sequence -Expected $Fixture.Names -Actual @($Plan.Artifacts.Name)
    foreach ($artifact in $Plan.Artifacts) {
        Assert-Equal -Expected $true -Actual ($artifact.Sha256 -cmatch '^[a-f0-9]{64}$')
        Assert-Equal -Expected (Get-Hash (Join-Path $Fixture.Directory $artifact.Name)) -Actual $artifact.Sha256
    }
}

function Write-ApprovedAssets {
    param($Fixture)
    $directory = $Fixture.Directory
    [IO.File]::WriteAllText((Join-Path $directory 'release-plan.json'), ($Fixture.Plan | ConvertTo-Json -Depth 10))
    [IO.File]::WriteAllText((Join-Path $directory 'release-notes.md'), $Fixture.Plan.Notes)
    $lines = foreach ($name in @($Fixture.Names) + @('release-plan.json', 'release-notes.md')) {
        "$(Get-Hash (Join-Path $directory $name))  $name"
    }
    [IO.File]::WriteAllLines((Join-Path $directory 'SHA256SUMS'), [string[]]$lines)
}

function Get-Snapshot {
    param($Fixture)
    @((Get-ChildItem -LiteralPath $Fixture.Directory -File | Sort-Object Name | ForEach-Object { "$($_.Name):$(Get-Hash $_.FullName)" }))
}

function Set-Context {
    param($Fixture)
    $env:GITHUB_REPOSITORY = $Fixture.Plan.Repository
    $env:RELEASE_REPOSITORY = $Fixture.Plan.Repository
    $env:GITHUB_SHA = $Fixture.Plan.Commit
    $env:GITHUB_EVENT_NAME = 'push'
    $env:GITHUB_REF = "refs/tags/$($Fixture.Plan.Tag)"
    [Environment]::SetEnvironmentVariable('NUGET_API_KEY', $null, 'Process')
}

function Invoke-Isolated {
    param([scriptblock]$Action)
    $savedEnvironment = @{}
    foreach ($name in $contextNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $exitVariable = Get-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $savedExit = if ($null -ne $exitVariable) { $exitVariable.Value } else { $null }
    $location = Get-Location
    $state = @{
        Queue = [Collections.Generic.List[object]]::new()
        Calls = [Collections.Generic.List[object]]::new()
        GuardErrors = [Collections.Generic.List[string]]::new()
        AllowGuardErrors = $false
    }
    # A wrapper also owns a $state variable. Use a test-specific name for dynamic scope lookup.
    $__releaseTestBoundaryState = $state
    function Invoke-FakeBoundary {
        param([string]$Command, [object[]]$Arguments)
        $boundary = $__releaseTestBoundaryState
        $copy = [string[]]@($Arguments | ForEach-Object { [string]$_ })
        # Function binding (unlike native binding) separates unquoted colon arguments.
        # Validate the complete raw shape before reconstructing the native argument vector.
        if ($Command -eq 'dotnet' -and $Arguments.Count -gt 0 -and $Arguments[0] -ceq 'msbuild') {
            try {
                Assert-Equal -Expected 7 -Actual $Arguments.Count
                Assert-Sequence -Expected @('-nologo', '-p:', 'Configuration=Release', '-getProperty:') -Actual @($Arguments[2..5])
                Assert-Sequence -Expected @('PackageVersion', 'PackageId') -Actual @($Arguments[6])
                $copy = @('msbuild', [string]$Arguments[1], '-nologo', '-p:Configuration=Release', '-getProperty:PackageVersion,PackageId')
            } catch {
                $boundary.GuardErrors.Add("raw arguments: $Command; $($_.Exception.Message)")
                throw
            }
        }
        $boundary.Calls.Add([pscustomobject]@{ Command = $Command; Arguments = $copy; RawArguments = $Arguments.Clone() })
        $global:LASTEXITCODE = 0
        $index = $boundary.Calls.Count - 1
        if ($index -ge $boundary.Queue.Count) {
            $boundary.GuardErrors.Add($Command)
            $global:LASTEXITCODE = 97
            throw "TEST GUARD: unexpected $Command"
        }
        $expected = $boundary.Queue[$index]
        try {
            Assert-Equal -Expected $expected.Command -Actual $Command
            if ($expected.DynamicDownload) {
                Assert-Sequence -Expected $expected.Arguments -Actual @($copy[0..7])
                Assert-Equal -Expected 9 -Actual $copy.Count
                Assert-Equal -Expected $true -Actual ([IO.Directory]::Exists($copy[8]))
                $destination = Join-Path $copy[8] $copy[6]
                [IO.File]::Copy($expected.Source, $destination)
                if ($expected.Corrupt) { [IO.File]::AppendAllText($destination, 'corrupt uploaded bytes') }
            } else {
                Assert-Sequence -Expected $expected.Arguments -Actual $copy
            }
        } catch {
            $boundary.GuardErrors.Add("arguments: $Command; $($_.Exception.Message)")
            throw
        }
        $global:LASTEXITCODE = $expected.ExitCode
        $expected.Output
    }
    # Ordinary functions intentionally receive native-style unbound arguments.
    function dotnet { Invoke-FakeBoundary -Command 'dotnet' -Arguments $args }
    function gh { Invoke-FakeBoundary -Command 'gh' -Arguments $args }
    function Invoke-WebRequest { Invoke-FakeBoundary -Command 'web' -Arguments $args }
    try {
        & $Action $state
        Assert-Equal -Expected $state.Queue.Count -Actual $state.Calls.Count
    } finally {
        foreach ($name in $contextNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
        if ($null -eq $exitVariable) { Remove-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue }
        else { $global:LASTEXITCODE = $savedExit }
        Set-Location -LiteralPath $location.Path
        if (-not $state.AllowGuardErrors -and $state.GuardErrors.Count) {
            throw "TEST GUARD: prohibited or incorrectly scripted transport: $($state.GuardErrors -join ', ')"
        }
    }
}

function Add-NativeResponse {
    param($State, [string]$Command, [string[]]$Arguments, $Output = $null, [int]$ExitCode = 0,
        [switch]$DynamicDownload, [string]$Source = '', [switch]$Corrupt)
    $State.Queue.Add([pscustomobject]@{
        Command = $Command; Arguments = $Arguments; Output = $Output; ExitCode = $ExitCode
        DynamicDownload = [bool]$DynamicDownload; Source = $Source; Corrupt = [bool]$Corrupt
    })
}

function Add-Evaluation {
    param($State, $Fixture, $Output, [int]$ExitCode = 0)
    Add-NativeResponse $State 'dotnet' @('msbuild', $Fixture.Project, '-nologo', '-p:Configuration=Release', '-getProperty:PackageVersion,PackageId') $Output $ExitCode
}

function Invoke-PlanWrapper {
    param($Fixture)
    & $planWrapper -Project $Fixture.Project -ChangelogPath $Fixture.ChangelogPath -ArtifactDirectory $Fixture.Directory `
        -Repository $Fixture.Parameters.Repository -EventName $Fixture.Parameters.EventName -Ref $Fixture.Parameters.Ref -Commit $Fixture.Parameters.Commit
}

function Assert-NoGeneratedAssets {
    param($Fixture)
    foreach ($name in 'release-plan.json', 'release-notes.md', 'SHA256SUMS') {
        Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $Fixture.Directory $name))
    }
}

# Harness self-tests keep failures of an assertion helper outside that helper's catch.
foreach ($row in @(
    @{ Name = 'NonThrowingAction'; Action = { Assert-Throws -Action {} -Message 'sentinel' }; Expected = 'Assertion: expected an exception, action returned normally.' },
    @{ Name = 'WrongMessage'; Action = { Assert-Throws -Action { throw 'actual' } -Message 'expected' }; Expected = "Assertion: expected 'expected' [String], got 'actual'." },
    @{ Name = 'WrongType'; Action = { Assert-Throws -Action { throw [IO.InvalidDataException]::new('bad') } -ExceptionType ([IO.FileNotFoundException]) }; Expected = "Assertion: expected 'System.IO.FileNotFoundException' [String], got 'System.IO.InvalidDataException'." },
    @{ Name = 'WrongCategory'; Action = { Assert-Throws -Action { throw 'bad' } -Category 'InvalidData' }; Expected = "Assertion: expected 'InvalidData' [String], got 'OperationStopped'." },
    @{ Name = 'WrongSequenceOrder'; Action = { Assert-Sequence @('a', 'b') @('b', 'a') }; Expected = "Assertion: expected 'a' [String], got 'b'." },
    @{ Name = 'WrongSequenceType'; Action = { Assert-Sequence @(1) @('1') }; Expected = "Assertion: expected '1' [Int32], got '1'." }
)) {
    Add-Case "Harness/Rejects$($row.Name)" {
        param($row)
        $caught = $null
        try { & $row.Action } catch { $caught = $_ }
        if ($null -eq $caught) { throw 'Helper self-test did not fail.' }
        Assert-Equal -Expected $row.Expected -Actual $caught.Exception.Message
    } $row
}
Add-Case 'Harness/NativeAndWebGuardsRejectUnexpectedCalls' {
    Invoke-Isolated {
        param($state)
        $state.AllowGuardErrors = $true
        foreach ($command in 'dotnet', 'gh', 'Invoke-WebRequest') {
            $boundary = if ($command -eq 'Invoke-WebRequest') { 'web' } else { $command }
            Assert-Throws -Action { & $command 'forbidden' } -Message "TEST GUARD: unexpected $boundary"
            Assert-Equal -Expected 97 -Actual $global:LASTEXITCODE
        }
        Assert-Sequence -Expected @('dotnet', 'gh', 'web') -Actual @($state.Calls.Command)
        foreach ($call in $state.Calls) { Assert-Sequence -Expected @('forbidden') -Actual $call.Arguments }
        # Intentional guard attempts are not queued successful responses.
        foreach ($call in $state.Calls) { $state.Queue.Add($call) }
    }
}
Add-Case 'Harness/ScopeRestoresStateAfterFailure' {
    $before = @{}
    foreach ($name in $contextNames) { $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $beforeExit = Get-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $beforeLocation = (Get-Location).Path
    $commands = @('dotnet', 'gh', 'Invoke-WebRequest') | ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue }
    Assert-Throws -Message 'scope sentinel' -Action {
        Invoke-Isolated {
            foreach ($name in $contextNames) { [Environment]::SetEnvironmentVariable($name, 'fake-test-only', 'Process') }
            $global:LASTEXITCODE = 54
            Set-Location -LiteralPath (New-OwnedDirectory)
            throw 'scope sentinel'
        }
    }
    foreach ($name in $contextNames) { Assert-Equal -Expected $before[$name] -Actual ([Environment]::GetEnvironmentVariable($name, 'Process')) }
    Assert-Equal -Expected $beforeLocation -Actual (Get-Location).Path
    $afterExit = Get-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    Assert-Equal -Expected ($null -eq $beforeExit) -Actual ($null -eq $afterExit)
    if ($null -ne $beforeExit) { Assert-Equal -Expected $beforeExit.Value -Actual $afterExit.Value }
    foreach ($command in $commands) { Assert-Equal -Expected $command.Definition -Actual (Get-Command $command.Name).Definition }
}

foreach ($value in '0.0.0', '1.2.3', '12.34.56', '1.2.3-rc.2', '1.2.3-rc.10', '1.2.3-alpha', '1.2.3-alpha-1.A9.0') {
    Add-Case "Version/AcceptsCanonical/$value" {
        param($value)
        $result = @(ConvertTo-ReleaseVersion $value)
        Assert-Equal -Expected 1 -Actual $result.Count
        Assert-Equal -Expected 'System.Management.Automation.SemanticVersion' -Actual $result[0].GetType().FullName
        Assert-Equal -Expected $value -Actual $result[0].ToString()
        $core = ($value -split '-', 2)[0] -split '\.'
        Assert-Equal -Expected ([int]$core[0]) -Actual $result[0].Major
        Assert-Equal -Expected ([int]$core[1]) -Actual $result[0].Minor
        Assert-Equal -Expected ([int]$core[2]) -Actual $result[0].Patch
    } $value
}
foreach ($value in 'v1.2.3', ' 1.2.3', '1.2.3 ', '1.2', '1.2.3.4', '-1.2.3', '+1.2.3', '01.2.3', '1.02.3', '1.2.03',
    '1.2.3+build', '1.2.3-rc.1+build', '1.2.3-', '1.2.3-alpha..1', '1.2.3-.alpha', '1.2.3-alpha.', '1.2.3-alpha_1', '1.2.3-01') {
    Add-Case "Version/RejectsNoncanonical/[$value]" {
        param($value)
        Assert-Throws -Message "Not a canonical release version: $value" -Action { ConvertTo-ReleaseVersion $value }
    } $value
}
foreach ($row in @(@{ Name = 'Null'; Value = $null }, @{ Name = 'Empty'; Value = '' })) {
    Add-Case "Version/RejectsMandatory$($row.Name)" {
        param($row)
        Assert-Throws -Category 'InvalidData' -ExceptionType ([psobject].Assembly.GetType('System.Management.Automation.ParameterBindingValidationException')) -Action { ConvertTo-ReleaseVersion -Value $row.Value }
    } $row
}
foreach ($row in @(@('1.10.0', '1.9.0', 1), @('1.2.3-rc.10', '1.2.3-rc.2', 1), @('1.2.3', '1.2.3-rc.10', 1), @('1.2.3', '1.2.3', 0))) {
    Add-Case "Version/NumericOrdering/$($row[0])/$($row[1])" {
        param($row)
        $left = ConvertTo-ReleaseVersion $row[0]
        $right = ConvertTo-ReleaseVersion $row[1]
        Assert-Equal -Expected $row[2] -Actual ([Math]::Sign($left.CompareTo($right)))
        Assert-Equal -Expected (-$row[2]) -Actual ([Math]::Sign($right.CompareTo($left)))
    } $row
}

foreach ($row in @(
    @{ Name = 'NamespacedRoot'; Namespace = $true; Entry = 'Owner.Library.nuspec'; File = 'package.nupkg' },
    @{ Name = 'UnqualifiedNested'; Namespace = $false; Entry = 'nested/Owner.Library.nuspec'; File = 'package.nupkg' },
    @{ Name = 'UppercaseExtensionLiteralWildcard'; Namespace = $true; Entry = 'nested/Owner.Library.NUSPEC'; File = 'package[1].nupkg' }
)) {
    Add-Case "Identity/ReadsRawFieldsAndEntries/$($row.Name)" {
        param($row)
        $path = Join-Path (New-OwnedDirectory) $row.File
        Write-Package $path (New-Nuspec -Namespace:$row.Namespace) 'lib/net10.0/a.pdb' $row.Entry
        $result = @(Read-PackageIdentity $path)
        Assert-Equal -Expected 1 -Actual $result.Count
        Assert-Equal -Expected 'Owner.Library' -Actual $result[0].Id
        Assert-Equal -Expected '1.2.3' -Actual $result[0].Version
        Assert-Equal -Expected $sha -Actual $result[0].Commit
        Assert-Sequence -Expected @($row.Entry, 'README.md', 'lib/net10.0/a.pdb') -Actual $result[0].Entries
    } $row
}
foreach ($row in @(
    @{ Name = 'ZeroNuspec'; Entries = [ordered]@{ 'README.md' = 'none' }; Message = 'Package must contain exactly one nuspec.' },
    @{ Name = 'TwoNuspecs'; Entries = [ordered]@{ 'a.nuspec' = '<package/>'; 'nested/b.nuspec' = '<package/>' }; Message = 'Package must contain exactly one nuspec.' },
    @{ Name = 'MissingMetadata'; Entries = [ordered]@{ 'a.nuspec' = '<package/>' }; Message = 'Package metadata is missing.' },
    @{ Name = 'MissingId'; Entries = [ordered]@{ 'a.nuspec' = (New-Nuspec -Omit id) }; Message = 'Package id, version, and repository metadata are required.' },
    @{ Name = 'MissingVersion'; Entries = [ordered]@{ 'a.nuspec' = (New-Nuspec -Omit version) }; Message = 'Package id, version, and repository metadata are required.' },
    @{ Name = 'MissingRepository'; Entries = [ordered]@{ 'a.nuspec' = (New-Nuspec -Omit repository) }; Message = 'Package id, version, and repository metadata are required.' }
)) {
    Add-Case "Identity/RequiresStructure/$($row.Name)" {
        param($row)
        $path = Join-Path (New-OwnedDirectory) 'package.nupkg'
        Write-Zip $path $row.Entries
        Assert-Throws -Message $row.Message -Action { Read-PackageIdentity $path }
        $stream = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
        $stream.Dispose()
        [IO.File]::Delete($path)
        Assert-Equal -Expected $false -Actual ([IO.File]::Exists($path))
    } $row
}
foreach ($row in @(
    @{ Name = 'PresentEmpty'; Xml = (New-Nuspec -Id '' -Version '' -Commit ''); Id = ''; Version = ''; Commit = '' },
    @{ Name = 'MissingCommit'; Xml = (New-Nuspec -Omit commit); Id = 'Owner.Library'; Version = '1.2.3'; Commit = '' },
    @{ Name = 'InvalidRawText'; Xml = (New-Nuspec -Id 'bad / id' -Version 'v1+build' -Commit 'NOT-A-SHA'); Id = 'bad / id'; Version = 'v1+build'; Commit = 'NOT-A-SHA' }
)) {
    Add-Case "Identity/RawParsingDoesNotInventValidation/$($row.Name)" {
        param($row)
        $path = Join-Path (New-OwnedDirectory) 'package.nupkg'
        Write-Package $path $row.Xml
        $identity = Read-PackageIdentity $path
        foreach ($field in 'Id', 'Version', 'Commit') { Assert-Equal -Expected $row[$field] -Actual $identity.$field }
        Assert-Sequence -Expected @('Owner.Library.nuspec', 'README.md') -Actual $identity.Entries
    } $row
}
foreach ($row in @(
    @{ Name = 'MalformedXml'; Xml = '<package><metadata>'; Type = [Xml.XmlException] },
    @{ Name = 'ProhibitedDtd'; Xml = '<!DOCTYPE package [<!ENTITY unsafe "expanded">]><package><metadata><id>&unsafe;</id></metadata></package>'; Type = [Xml.XmlException] },
    @{ Name = 'MissingZip'; Xml = $null; Type = [IO.FileNotFoundException] },
    @{ Name = 'CorruptZip'; Xml = 'corrupt'; Type = [IO.InvalidDataException] }
)) {
    Add-Case "Identity/RejectsUnsafeInputAndReleasesHandles/$($row.Name)" {
        param($row)
        $path = Join-Path (New-OwnedDirectory) 'package.nupkg'
        if ($row.Name -eq 'CorruptZip') { [IO.File]::WriteAllText($path, 'not a zip archive') }
        elseif ($null -ne $row.Xml) { Write-Package $path $row.Xml }
        Assert-Throws -ExceptionType $row.Type -Action { Read-PackageIdentity $path }
        if ([IO.File]::Exists($path)) {
            $stream = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
            $stream.Dispose()
            [IO.File]::Delete($path)
        }
        Write-Package $path (New-Nuspec)
        Assert-Equal -Expected 'Owner.Library' -Actual (Read-PackageIdentity $path).Id
        $stream = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
        $stream.Dispose()
        [IO.File]::Delete($path)
        Assert-Equal -Expected $false -Actual ([IO.File]::Exists($path))
    } $row
}

foreach ($version in '1.2.3', '1.2.3-rc.10') {
    Add-Case "Plan/CreatesExactPlan/$version" {
        param($version)
        $f = New-Fixture -Version $version
        $parameters = $f.Parameters
        $result = @(New-LibraryReleasePlan @parameters)
        Assert-Equal -Expected 1 -Actual $result.Count
        Assert-Plan $result[0] $f
    } $version
}

# Each invalid field starts from independently valid artifacts and notes.
$planFields = @(
    @{ Field = 'Repository'; Values = @('owner', 'owner/library/extra', '/library', 'owner/', 'own er/library'); Message = 'Invalid repository.' },
    @{ Field = 'EventName'; Values = @('pull_request', 'Push'); Message = 'Only a version-tag push may publish.' },
    @{ Field = 'Ref'; Values = @('refs/heads/v1.2.3', 'Refs/tags/v1.2.3', 'refs/tags/V1.2.3'); Message = 'Only a version-tag push may publish.' },
    @{ Field = 'Commit'; Values = @($sha.Substring(1), ($sha + '0'), $sha.ToUpperInvariant(), ('g' * 40)); Message = 'Expected the exact source commit SHA.' },
    @{ Field = 'PackageId'; Values = @('.Library', '-Library', 'Owner/Library', 'Owner Library'); Message = 'Invalid package ID.' }
)
foreach ($field in $planFields) {
    foreach ($value in $field.Values) {
        Add-Case "Plan/Rejects$($field.Field)/[$value]" {
            param($row)
            $f = New-Fixture
            $parameters = $f.Parameters.Clone()
            $parameters[$row.Field] = $row.Value
            Assert-Throws -Message $row.Message -Action { New-LibraryReleasePlan @parameters }
            Assert-Equal -Expected 2 -Actual @(Get-ChildItem -LiteralPath $f.Directory -File).Count
        } @{ Field = $field.Field; Value = $value; Message = $field.Message }
    }
}
foreach ($row in @(
    @{ Name = 'RepositoryBoundary'; Repository = 'A_.-/b-._'; Id = 'Owner.Library' },
    @{ Name = 'OneCharacterId'; Repository = 'owner/library'; Id = 'A' },
    @{ Name = 'UnderscoreId'; Repository = 'owner/library'; Id = '_' },
    @{ Name = 'InteriorIdPunctuation'; Repository = 'owner/library'; Id = 'A_b.c-d' }
)) {
    Add-Case "Plan/AcceptsIdentityBoundary/$($row.Name)" {
        param($row)
        $f = New-Fixture -Id $row.Id -Repository $row.Repository
        Assert-Plan $f.Plan $f
    } $row
}
foreach ($field in 'Repository', 'EventName', 'Ref', 'Commit', 'ProjectVersion', 'PackageId', 'Changelog', 'ArtifactDirectory') {
    foreach ($kind in 'Empty', 'Null') {
        Add-Case "Plan/RequiresMandatoryString/$field/$kind" {
            param($row)
            $f = New-Fixture
            $parameters = $f.Parameters.Clone()
            $parameters[$row.Field] = if ($row.Kind -eq 'Null') { $null } else { '' }
            Assert-Throws -Category 'InvalidData' -Action { New-LibraryReleasePlan @parameters }
        } @{ Field = $field; Kind = $kind }
    }
}
foreach ($row in @(
    @{ Name = 'RepositoryBeforeFiles'; Field = 'Repository'; Value = 'bad'; Message = 'Invalid repository.' },
    @{ Name = 'ContextBeforeNotes'; Field = 'EventName'; Value = 'pull_request'; Message = 'Only a version-tag push may publish.' }
)) {
    Add-Case "Plan/EarlyGate/$($row.Name)" {
        param($row)
        $f = New-Fixture
        $parameters = $f.Parameters.Clone()
        $parameters.ArtifactDirectory = Join-Path $f.Root 'absent'
        $parameters.Changelog = 'not a release heading'
        $parameters[$row.Field] = $row.Value
        Assert-Throws -Message $row.Message -Action { New-LibraryReleasePlan @parameters }
    } $row
}
foreach ($row in @(
    @{ Name = 'DifferentProject'; Ref = 'refs/tags/v1.2.3'; Version = '1.2.4'; Error = 'Tag and evaluated project version differ.' },
    @{ Name = 'CaseDifferentPrerelease'; Ref = 'refs/tags/v1.2.3-rc.1'; Version = '1.2.3-RC.1'; Error = 'Tag and evaluated project version differ.' },
    @{ Name = 'TagMetadata'; Ref = 'refs/tags/v1.2.3+build'; Version = '1.2.3'; Error = 'Not a canonical release version: 1.2.3+build' },
    @{ Name = 'ProjectMetadata'; Ref = 'refs/tags/v1.2.3'; Version = '1.2.3+build'; Error = 'Not a canonical release version: 1.2.3+build' },
    @{ Name = 'InvalidTag'; Ref = 'refs/tags/v01.2.3'; Version = '1.2.3'; Error = 'Not a canonical release version: 01.2.3' },
    @{ Name = 'InvalidProject'; Ref = 'refs/tags/v1.2.3'; Version = 'v1.2.3'; Error = 'Not a canonical release version: v1.2.3' }
)) {
    Add-Case "Plan/VersionAgreement/$($row.Name)" {
        param($row)
        $f = New-Fixture
        $parameters = $f.Parameters.Clone()
        $parameters.Ref = $row.Ref
        $parameters.ProjectVersion = $row.Version
        Assert-Throws -Message $row.Error -Action { New-LibraryReleasePlan @parameters }
    } $row
}
foreach ($newline in @(@{ Name = 'LF'; Value = "`n" }, @{ Name = 'CRLF'; Value = "`r`n" })) {
    Add-Case "Plan/ExtractsOnlyDatedNotes/$($newline.Name)" {
        param($newline)
        $f = New-Fixture
        $parameters = $f.Parameters.Clone()
        $parameters.Changelog = (@('# Changes', '## [1x2x3] - 2024-02-29', 'decoy', '## [1.2.3] - 2024-02-29', '', '  precise notes  ', '', '## Other heading', 'not notes') -join $newline.Value)
        $plan = New-LibraryReleasePlan @parameters
        Assert-Equal -Expected 'precise notes' -Actual $plan.Notes
        Assert-Sequence -Expected $f.Names -Actual @($plan.Artifacts.Name)
    } $newline
}
foreach ($row in @(
    @{ Name = 'Missing'; Text = '# Changes'; Error = 'Expected exactly one dated changelog section for the version.' },
    @{ Name = 'RegexDecoyOnly'; Text = "## [1x2x3] - 2024-02-29`nnotes"; Error = 'Expected exactly one dated changelog section for the version.' },
    @{ Name = 'Duplicate'; Text = "## [1.2.3] - 2024-02-29`nfirst`n## [1.2.3] - 2024-03-01`nsecond"; Error = 'Expected exactly one dated changelog section for the version.' },
    @{ Name = 'Undated'; Text = "## [1.2.3]`nnotes"; Error = 'Expected exactly one dated changelog section for the version.' },
    @{ Name = 'MalformedDate'; Text = "## [1.2.3] - 2024-2-29`nnotes"; Error = 'Expected exactly one dated changelog section for the version.' },
    @{ Name = 'Empty'; Text = '## [1.2.3] - 2024-02-29'; Error = 'Release notes are empty.' },
    @{ Name = 'Whitespace'; Text = "## [1.2.3] - 2024-02-29`n `t`n"; Error = 'Release notes are empty.' },
    @{ Name = 'AdjacentHeading'; Text = "## [1.2.3] - 2024-02-29`n## Next`nother"; Error = 'Release notes are empty.' }
)) {
    Add-Case "Plan/RejectsNotes/$($row.Name)" {
        param($row)
        $f = New-Fixture
        $parameters = $f.Parameters.Clone()
        $parameters.Changelog = $row.Text
        Assert-Throws -Message $row.Error -Action { New-LibraryReleasePlan @parameters }
    } $row
}
Add-Case 'Plan/RejectsImpossibleCalendarDate' {
    $f = New-Fixture
    $parameters = $f.Parameters.Clone()
    $parameters.Changelog = "## [1.2.3] - 2023-02-29`nnotes"
    Assert-Throws -ExceptionType ([FormatException]) -Action { New-LibraryReleasePlan @parameters }
}

foreach ($mode in 'Zero', 'One', 'Three', 'TwoNupkg', 'TwoSnupkg', 'WrongName', 'WrongCase', 'NestedOnly', 'UnrelatedText', 'MissingDirectory') {
    Add-Case "Plan/RequiresExactTopLevelPair/$mode" {
        param($mode)
        $f = New-Fixture
        $first = Join-Path $f.Directory $f.Names[0]
        $second = Join-Path $f.Directory $f.Names[1]
        $parameters = $f.Parameters.Clone()
        switch ($mode) {
            Zero { [IO.File]::Delete($first); [IO.File]::Delete($second) }
            One { [IO.File]::Delete($second) }
            Three { [IO.File]::Copy($first, (Join-Path $f.Directory 'extra.nupkg')) }
            TwoNupkg { [IO.File]::Move($second, (Join-Path $f.Directory 'other.nupkg')) }
            TwoSnupkg { [IO.File]::Move($first, (Join-Path $f.Directory 'other.snupkg')) }
            WrongName { [IO.File]::Move($first, (Join-Path $f.Directory 'Wrong.1.2.3.nupkg')) }
            WrongCase {
                $temporary = Join-Path $f.Directory 'rename.tmp'
                [IO.File]::Move($first, $temporary)
                [IO.File]::Move($temporary, (Join-Path $f.Directory $f.Names[0].ToLowerInvariant()))
            }
            NestedOnly {
                $nested = [IO.Directory]::CreateDirectory((Join-Path $f.Directory 'nested')).FullName
                [IO.File]::Move($second, (Join-Path $nested $f.Names[1]))
            }
            UnrelatedText { [IO.File]::WriteAllText((Join-Path $f.Directory 'extra.txt'), 'allowed') }
            MissingDirectory { $parameters.ArtifactDirectory = Join-Path $f.Root 'missing' }
        }
        if ($mode -eq 'UnrelatedText') {
            $plan = New-LibraryReleasePlan @parameters
            Assert-Plan $plan $f
        } elseif ($mode -eq 'MissingDirectory') {
            Assert-Throws -Category 'ObjectNotFound' -Action { New-LibraryReleasePlan @parameters }
        } else {
            $message = if ($mode -in 'Zero', 'One', 'Three', 'NestedOnly') { 'Expected one nupkg and its snupkg, and no other packages.' }
            elseif ($mode -eq 'TwoNupkg') { "Missing expected artifact: $($f.Names[1])" }
            else { "Missing expected artifact: $($f.Names[0])" }
            Assert-Throws -Message $message -Action { New-LibraryReleasePlan @parameters }
        }
    } $mode
}

$identityMutations = @(
    @{ Name = 'WrongId'; Id = 'Other.Library' }, @{ Name = 'EmptyId'; Id = '' },
    @{ Name = 'InvalidId'; Id = 'bad / id' }, @{ Name = 'IdCase'; Id = 'owner.library' }, @{ Name = 'MissingId'; Omit = 'id' },
    @{ Name = 'WrongVersion'; Version = '1.2.4' }, @{ Name = 'EmptyVersion'; Version = '' },
    @{ Name = 'InvalidVersion'; Version = 'v1.2.3' }, @{ Name = 'MetadataVersion'; Version = '1.2.3+build' }, @{ Name = 'MissingVersion'; Omit = 'version' },
    @{ Name = 'WrongCommit'; Commit = ('a' * 40) }, @{ Name = 'EmptyCommit'; Commit = '' },
    @{ Name = 'InvalidCommit'; Commit = ('g' * 40) }, @{ Name = 'CommitCase'; Commit = $sha.ToUpperInvariant() },
    @{ Name = 'MissingCommit'; Omit = 'commit' }, @{ Name = 'MissingRepository'; Omit = 'repository' }
)
foreach ($index in 0, 1) {
    foreach ($mutation in $identityMutations) {
        foreach ($api in 'Plan', 'Artifacts') {
            Add-Case "$api/RejectsPackageIdentity/$index/$($mutation.Name)" {
                param($row)
                $f = New-Fixture
                $xmlParameters = $row.Mutation.Clone()
                $xmlParameters.Remove('Name')
                $path = Join-Path $f.Directory $f.Names[$row.Index]
                Write-Package $path (New-Nuspec @xmlParameters) 'nested/valid.pdb'
                if ($row.Api -eq 'Artifacts') { $f.Plan.Artifacts[$row.Index].Sha256 = Get-Hash $path }
                $missingNode = $xmlParameters.ContainsKey('Omit') -and $xmlParameters.Omit -in 'id', 'version', 'repository'
                $message = if ($missingNode) { 'Package id, version, and repository metadata are required.' }
                elseif ($row.Api -eq 'Plan') { "Package identity/provenance mismatch: $($f.Names[$row.Index])" }
                else { "Artifact provenance mismatch: $($f.Names[$row.Index])" }
                if ($row.Api -eq 'Plan') {
                    $parameters = $f.Parameters
                    Assert-Throws -Message $message -Action { New-LibraryReleasePlan @parameters }
                } else {
                    Assert-Equal -Expected (Get-Hash $path) -Actual $f.Plan.Artifacts[$row.Index].Sha256
                    Assert-Throws -Message $message -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
                }
            } @{ Api = $api; Index = $index; Mutation = $mutation }
        }
    }
}
foreach ($pdb in '', 'lib/a.pdb.txt', 'nested/deeper/a.PDB') {
    Add-Case "Plan/RequiresSymbolPdb/[$pdb]" {
        param($pdb)
        $f = New-Fixture
        Write-Package (Join-Path $f.Directory $f.Names[1]) (New-Nuspec) $pdb
        $parameters = $f.Parameters
        if ($pdb -eq 'nested/deeper/a.PDB') { Assert-Plan (New-LibraryReleasePlan @parameters) $f }
        else { Assert-Throws -Message 'The symbol package contains no PDB.' -Action { New-LibraryReleasePlan @parameters } }
    } $pdb
}

$latestRows = @(
    @{ Name = 'Empty'; Version = '1.2.3'; Other = @(); Expected = $true },
    @{ Name = 'Older'; Version = '1.2.3'; Other = @('1.2.2'); Expected = $true },
    @{ Name = 'UnorderedOlder'; Version = '1.2.3'; Other = @('1.1.9', '0.9.0', '1.2.2'); Expected = $true },
    @{ Name = 'Equal'; Version = '1.2.3'; Other = @('1.2.3'); Expected = $false },
    @{ Name = 'NewerPatch'; Version = '1.2.3'; Other = @('1.2.4'); Expected = $false },
    @{ Name = 'NewerMinorLast'; Version = '1.2.3'; Other = @('1.2.2', '1.3.0'); Expected = $false },
    @{ Name = 'NewerThenOlder'; Version = '1.2.3'; Other = @('1.3.0', '1.0.0'); Expected = $false },
    @{ Name = 'NumericMinor'; Version = '1.10.0'; Other = @('1.9.0'); Expected = $true },
    @{ Name = 'OlderNumericMinor'; Version = '1.9.0'; Other = @('1.10.0'); Expected = $false },
    @{ Name = 'Rc2'; Version = '1.2.3-rc.2'; Other = @(); Expected = $false },
    @{ Name = 'Rc10'; Version = '1.2.3-rc.10'; Other = @('1.0.0'); Expected = $false },
    @{ Name = 'Alpha'; Version = '1.2.3-alpha'; Other = @(); Expected = $false },
    @{ Name = 'PrereleaseShortCircuit'; Version = '1.2.3-rc.1'; Other = @('invalid'); Expected = $false },
    @{ Name = 'EqualShortCircuit'; Version = '1.2.3'; Other = @('1.2.3', 'invalid'); Expected = $false },
    @{ Name = 'NewerShortCircuit'; Version = '1.2.3'; Other = @('2.0.0', 'invalid'); Expected = $false }
)
foreach ($row in $latestRows) {
    Add-Case "Latest/StableNumericPolicy/$($row.Name)" {
        param($row)
        $result = @(Test-ReleaseIsLatest $row.Version $row.Other)
        Assert-Equal -Expected 1 -Actual $result.Count
        Assert-Equal -Expected $row.Expected -Actual $result[0]
    } $row
}
foreach ($row in @(
    @{ Name = 'MalformedPublished'; Other = 'garbage'; Error = 'Not a canonical release version: garbage' },
    @{ Name = 'PrereleasePublished'; Other = '1.2.0-rc.1'; Error = 'Stable release list contains a prerelease.' }
)) {
    Add-Case "Latest/RejectsReachedInvalidVersion/$($row.Name)" {
        param($row)
        Assert-Throws -Message $row.Error -Action { Test-ReleaseIsLatest '1.2.3' @('1.0.0', $row.Other) }
    } $row
}

foreach ($version in '1.2.3', '1.2.3-rc.10') {
    Add-Case "Artifacts/AcceptsValidPlanWithLiteralWildcardPath/$version" {
        param($version)
        $f = New-Fixture -Version $version -Wildcard
        [IO.File]::WriteAllText((Join-Path $f.Directory 'unrelated.txt'), 'not a package')
        Assert-Equal -Expected 0 -Actual @(Assert-ReleaseArtifacts $f.Plan $f.Directory).Count
        Assert-Plan $f.Plan $f
    } $version
}
foreach ($row in @(
    @{ Name = 'SchemaZero'; Field = 'SchemaVersion'; Value = 0; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaTwo'; Field = 'SchemaVersion'; Value = 2; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaNegative'; Field = 'SchemaVersion'; Value = -1; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaString'; Field = 'SchemaVersion'; Value = '1'; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaBoolean'; Field = 'SchemaVersion'; Value = $true; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaDouble'; Field = 'SchemaVersion'; Value = [double]1; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaDecimal'; Field = 'SchemaVersion'; Value = [decimal]1; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaShort'; Field = 'SchemaVersion'; Value = [short]1; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaByte'; Field = 'SchemaVersion'; Value = [byte]1; Error = 'Unsupported release plan schema.' },
    @{ Name = 'SchemaNull'; Field = 'SchemaVersion'; Value = $null; Error = 'Unsupported release plan schema.' },
    @{ Name = 'FlagNull'; Field = 'Prerelease'; Value = $null; Error = 'Invalid prerelease flag.' },
    @{ Name = 'FlagStringFalse'; Field = 'Prerelease'; Value = 'false'; Error = 'Invalid prerelease flag.' },
    @{ Name = 'FlagStringTrue'; Field = 'Prerelease'; Value = 'true'; Error = 'Invalid prerelease flag.' },
    @{ Name = 'FlagZero'; Field = 'Prerelease'; Value = 0; Error = 'Invalid prerelease flag.' },
    @{ Name = 'FlagOne'; Field = 'Prerelease'; Value = 1; Error = 'Invalid prerelease flag.' },
    @{ Name = 'WrongStableFlag'; Field = 'Prerelease'; Value = $true; Error = 'Invalid prerelease flag.' }
)) {
    Add-Case "Artifacts/RejectsSchemaAndFlag/$($row.Name)" {
        param($row)
        $f = New-Fixture
        $f.Plan.($row.Field) = $row.Value
        Assert-Throws -Message $row.Error -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
    } $row
}
Add-Case 'Artifacts/AcceptsInt64SchemaFromJson' {
    $f = New-Fixture
    $f.Plan = $f.Plan | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    Assert-Equal -Expected ([long]1) -Actual $f.Plan.SchemaVersion
    Assert-Equal -Expected 0 -Actual @(Assert-ReleaseArtifacts $f.Plan $f.Directory).Count
}
Add-Case 'Artifacts/RejectsWrongPrereleaseFlag' {
    $f = New-Fixture -Version '1.2.3-rc.1'
    $f.Plan.Prerelease = $false
    Assert-Throws -Message 'Invalid prerelease flag.' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
}
foreach ($field in 'SchemaVersion', 'Prerelease', 'Version', 'Repository', 'Commit', 'PackageId', 'Tag', 'Artifacts') {
    Add-Case "Artifacts/RejectsMissingProperty/$field" {
        param($field)
        $f = New-Fixture
        $f.Plan.PSObject.Properties.Remove($field)
        Assert-Throws -Category 'NotSpecified' -ErrorId 'PropertyNotFoundStrict,Assert-ReleaseArtifacts' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
    } $field
}
foreach ($row in @(
    @{ Field = 'Tag'; Values = @('v1.2.4', 'V1.2.3', 'v1.2.3-RC.1', '') },
    @{ Field = 'Repository'; Values = @('', 'invalid', 'owner/other/extra', 'owner/ ') },
    @{ Field = 'Commit'; Values = @('', $sha.Substring(1), ($sha + '0'), $sha.ToUpperInvariant(), ('g' * 40)) },
    @{ Field = 'PackageId'; Values = @('', '.invalid', 'bad/id', 'bad id') }
)) {
    foreach ($value in $row.Values) {
        Add-Case "Artifacts/RejectsIdentity/$($row.Field)/[$value]" {
            param($data)
            $f = New-Fixture
            $f.Plan.($data.Field) = $data.Value
            Assert-Throws -Message 'Invalid release plan identity.' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
        } @{ Field = $row.Field; Value = $value }
    }
}
foreach ($value in 'v1.2.3', '1.2.3+build', '', $null) {
    Add-Case "Artifacts/RejectsVersion/[$value]/$($null -eq $value)" {
        param($value)
        $f = New-Fixture
        $f.Plan.Version = $value
        if ([string]::IsNullOrEmpty($value)) { Assert-Throws -Category 'InvalidData' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory } }
        else { Assert-Throws -Message "Not a canonical release version: $value" -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory } }
    } $value
}
foreach ($mode in 'Zero', 'One', 'Three', 'Duplicate', 'MissingExpected', 'CaseName', 'Rooted', 'Traversal', 'NullName', 'MissingName',
    'NullHash', 'MissingHash', 'ShortHash', 'InvalidHash', 'UppercaseHash', 'NullRecord') {
    Add-Case "Artifacts/RejectsManifest/$mode" {
        param($mode)
        $f = New-Fixture
        switch ($mode) {
            Zero { $f.Plan.Artifacts = @() }
            One { $f.Plan.Artifacts = @($f.Plan.Artifacts[0]) }
            Three { $f.Plan.Artifacts += $f.Plan.Artifacts[0] }
            Duplicate { $f.Plan.Artifacts[1].Name = $f.Names[0] }
            MissingExpected { $f.Plan.Artifacts[0].Name = 'other.nupkg' }
            CaseName { $f.Plan.Artifacts[0].Name = $f.Names[0].ToLowerInvariant() }
            Rooted { $f.Plan.Artifacts[0].Name = Join-Path $f.Root $f.Names[0] }
            Traversal { $f.Plan.Artifacts[0].Name = "../$($f.Names[0])" }
            NullName { $f.Plan.Artifacts[0].Name = $null }
            MissingName { $f.Plan.Artifacts[0].PSObject.Properties.Remove('Name') }
            NullHash { $f.Plan.Artifacts[0].Sha256 = $null }
            MissingHash { $f.Plan.Artifacts[0].PSObject.Properties.Remove('Sha256') }
            ShortHash { $f.Plan.Artifacts[0].Sha256 = 'a' * 63 }
            InvalidHash { $f.Plan.Artifacts[0].Sha256 = 'g' * 64 }
            UppercaseHash { $f.Plan.Artifacts[0].Sha256 = 'A' * 64 }
            NullRecord { $f.Plan.Artifacts[0] = $null }
        }
        if ($mode -eq 'MissingHash') {
            Assert-Throws -Category 'NotSpecified' -ErrorId 'PropertyNotFoundStrict,Assert-ReleaseArtifacts' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
        } elseif ($mode -eq 'MissingName') {
            Assert-Throws -Category 'InvalidArgument' -ErrorId 'PropertyNotFound,Microsoft.PowerShell.Commands.WhereObjectCommand' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
        } elseif ($mode -eq 'NullRecord') {
            Assert-Throws -Category 'InvalidArgument' -ErrorId 'InputObjectIsNull,Microsoft.PowerShell.Commands.WhereObjectCommand' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
        } else {
            $message = if ($mode -in 'Zero', 'One', 'Three') { 'Expected two package artifacts.' } else { 'Invalid artifact manifest.' }
            Assert-Throws -Message $message -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
        }
    } $mode
}
foreach ($index in 0, 1) {
    foreach ($mode in 'Missing', 'ChangedBytes', 'HashOnly') {
        Add-Case "Artifacts/RejectsFiles/$index/$mode" {
            param($row)
            $f = New-Fixture
            $name = $f.Names[$row.Index]
            $path = Join-Path $f.Directory $name
            switch ($row.Mode) {
                Missing { [IO.File]::Delete($path) }
                ChangedBytes { [IO.File]::AppendAllText($path, 'tampered') }
                HashOnly { $f.Plan.Artifacts[$row.Index].Sha256 = '0' * 64 }
            }
            if ($row.Mode -eq 'Missing') { Assert-Throws -Category 'ObjectNotFound' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory } }
            else { Assert-Throws -Message "Artifact checksum mismatch: $name" -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory } }
        } @{ Index = $index; Mode = $mode }
    }
}

foreach ($version in '1.2.3', '1.2.3-rc.10') {
    Add-Case "Release/WhatIfValidatesButNeverTransports/$version" {
        param($version)
        $f = New-Fixture -Version $version
        $calls = [Collections.Generic.List[string]]::new()
        $before = Get-Snapshot $f
        $result = @(Invoke-LibraryRelease $f.Plan $f.Directory { param($step) $calls.Add($step); throw 'transport forbidden' } -WhatIf)
        Assert-Equal -Expected 1 -Actual $result.Count
        Assert-Equal -Expected 'NotPublished' -Actual $result[0].Status
        Assert-Sequence -Expected @() -Actual $result[0].Completed
        Assert-Equal -Expected 0 -Actual $calls.Count
        Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
    } $version
}
foreach ($mode in 'Hash', 'Identity', 'Schema') {
    Add-Case "Release/WhatIfRejectsInvalidPlan/$mode" {
        param($mode)
        $f = New-Fixture
        $calls = [Collections.Generic.List[string]]::new()
        $message = switch ($mode) {
            Hash { $f.Plan.Artifacts[0].Sha256 = '0' * 64; "Artifact checksum mismatch: $($f.Names[0])" }
            Identity { $f.Plan.Commit = 'invalid'; 'Invalid release plan identity.' }
            Schema { $f.Plan.SchemaVersion = 2; 'Unsupported release plan schema.' }
        }
        Assert-Throws -Message $message -Action {
            Invoke-LibraryRelease $f.Plan $f.Directory { param($step) $calls.Add($step) } -WhatIf
        }
        Assert-Equal -Expected 0 -Actual $calls.Count
    } $mode
}
foreach ($mode in 'NoisyOutput', 'FailureShapedReturn') {
    Add-Case "Release/CompletesOrderedStepsAndSuppressesOutput/$mode" {
        param($mode)
        $f = New-Fixture
        $calls = [Collections.Generic.List[object]]::new()
        $before = Get-Snapshot $f
        $result = @(Invoke-LibraryRelease $f.Plan $f.Directory {
            param($step, $plan, $directory)
            $calls.Add([pscustomobject]@{ Step = $step; Plan = $plan; Directory = $directory })
            if ($mode -eq 'FailureShapedReturn') { [pscustomobject]@{ Success = $false; Error = 'not an exception' } }
            else { 'noise'; 42; $false }
        } -Confirm:$false)
        Assert-Equal -Expected 1 -Actual $result.Count
        Assert-Equal -Expected 'Published' -Actual $result[0].Status
        Assert-Sequence -Expected $steps -Actual $result[0].Completed
        Assert-Sequence -Expected $steps -Actual @($calls.Step)
        foreach ($call in $calls) {
            Assert-Equal -Expected $true -Actual ([object]::ReferenceEquals($f.Plan, $call.Plan))
            Assert-Equal -Expected $f.Directory -Actual $call.Directory
        }
        Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
    } $mode
}
foreach ($failedIndex in 0..7) {
    Add-Case "Release/StopsAndReportsAtEachFailedStep/$($steps[$failedIndex])" {
        param($failedIndex)
        $f = New-Fixture
        $calls = [Collections.Generic.List[string]]::new()
        $before = Get-Snapshot $f
        $completed = @($steps | Select-Object -First $failedIndex)
        $failedStep = $steps[$failedIndex]
        $message = "Release failed at $failedStep. Completed: $($completed -join ', '). Keep original artifacts and draft for explicit recovery. injected-$failedStep"
        Assert-Throws -Message $message -Action {
            Invoke-LibraryRelease $f.Plan $f.Directory {
                param($step, $plan, $directory)
                Assert-Equal -Expected $true -Actual ([object]::ReferenceEquals($plan, $f.Plan))
                Assert-Equal -Expected $f.Directory -Actual $directory
                $calls.Add($step)
                if ($step -ceq $failedStep) { throw "injected-$failedStep" }
                'suppressed'
            } -Confirm:$false
        }
        Assert-Sequence -Expected @($steps | Select-Object -First ($failedIndex + 1)) -Actual @($calls)
        Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
    } $failedIndex
}

# Direct wrapper invocation: these do not substitute common-function calls for wrapper coverage.
foreach ($row in @(
    @{ Name = 'StableCompact'; Version = '1.2.3'; Pretty = $false },
    @{ Name = 'PrereleaseMultiline'; Version = '1.2.3-rc.10'; Pretty = $true }
)) {
    Add-Case "PlanWrapper/EvaluatedPropertiesAndExactFiles/$($row.Name)" {
        param($row)
        $f = New-Fixture -Version $row.Version
        Invoke-Isolated {
            param($state)
            $json = @{ Properties = @{ PackageVersion = $row.Version; PackageId = 'Owner.Library' } } | ConvertTo-Json -Compress:(-not $row.Pretty)
            Add-Evaluation $state $f ($json -split "`n")
            $output = @(Invoke-PlanWrapper $f 6>&1)
            Assert-Equal -Expected 1 -Actual $output.Count
            Assert-Equal -Expected 'System.Management.Automation.InformationRecord' -Actual $output[0].GetType().FullName
            Assert-Equal -Expected "Validated Owner.Library $($row.Version) at $sha; no publication performed." -Actual $output[0].MessageData.ToString()
            $plan = [IO.File]::ReadAllText((Join-Path $f.Directory 'release-plan.json')) | ConvertFrom-Json
            # JSON represents numbers as Int64; all other types are checked by Assert-Plan.
            Assert-Equal -Expected ([long]1) -Actual $plan.SchemaVersion
            $plan.SchemaVersion = [int]$plan.SchemaVersion
            Assert-Plan $plan $f
            $notes = [IO.File]::ReadAllText((Join-Path $f.Directory 'release-notes.md'))
            Assert-Equal -Expected ($f.Notes + [Environment]::NewLine) -Actual $notes
            $names = @($f.Names) + @('release-plan.json', 'release-notes.md')
            $expectedLines = @($names | ForEach-Object { "$(Get-Hash (Join-Path $f.Directory $_))  $_" })
            Assert-Sequence -Expected $expectedLines -Actual ([IO.File]::ReadAllLines((Join-Path $f.Directory 'SHA256SUMS')))
            Assert-Sequence -Expected @(@($names) + @('SHA256SUMS') | Sort-Object) -Actual @(Get-ChildItem -LiteralPath $f.Directory -File | Select-Object -ExpandProperty Name | Sort-Object)
            Assert-Equal -Expected 1 -Actual $state.Calls.Count
        }
    } $row
}
foreach ($row in @(
    @{ Name = 'NativeFailure'; Json = '{"Properties":{"PackageVersion":"1.2.3","PackageId":"Owner.Library"}}'; Exit = 13; Error = 'Failed to evaluate package properties.' },
    @{ Name = 'MalformedJson'; Json = '{broken'; Exit = 0; Category = 'NotSpecified' },
    @{ Name = 'MissingProperties'; Json = '{}'; Exit = 0; Category = 'NotSpecified' },
    @{ Name = 'MissingVersion'; Json = '{"Properties":{"PackageId":"Owner.Library"}}'; Exit = 0; Category = 'NotSpecified' },
    @{ Name = 'MissingId'; Json = '{"Properties":{"PackageVersion":"1.2.3"}}'; Exit = 0; Category = 'NotSpecified' },
    @{ Name = 'NullVersion'; Json = '{"Properties":{"PackageVersion":null,"PackageId":"Owner.Library"}}'; Exit = 0; Category = 'InvalidData' },
    @{ Name = 'EmptyVersion'; Json = '{"Properties":{"PackageVersion":"","PackageId":"Owner.Library"}}'; Exit = 0; Category = 'InvalidData' },
    @{ Name = 'NullId'; Json = '{"Properties":{"PackageVersion":"1.2.3","PackageId":null}}'; Exit = 0; Category = 'InvalidData' },
    @{ Name = 'EmptyId'; Json = '{"Properties":{"PackageVersion":"1.2.3","PackageId":""}}'; Exit = 0; Category = 'InvalidData' },
    @{ Name = 'DisagreeingVersion'; Json = '{"Properties":{"PackageVersion":"1.2.4","PackageId":"Owner.Library"}}'; Exit = 0; Error = 'Tag and evaluated project version differ.' },
    @{ Name = 'InvalidId'; Json = '{"Properties":{"PackageVersion":"1.2.3","PackageId":"bad/id"}}'; Exit = 0; Error = 'Invalid package ID.' }
)) {
    Add-Case "PlanWrapper/RejectsEvaluation/$($row.Name)" {
        param($row)
        $f = New-Fixture
        Invoke-Isolated {
            param($state)
            Add-Evaluation $state $f $row.Json $row.Exit
            if ($row.ContainsKey('Error')) { Assert-Throws -Message $row.Error -Action { Invoke-PlanWrapper $f } }
            else { Assert-Throws -Category $row.Category -Action { Invoke-PlanWrapper $f } }
            Assert-NoGeneratedAssets $f
            Assert-Equal -Expected 1 -Actual $state.Calls.Count
        }
    } $row
}
foreach ($valid in $true, $false) {
    Add-Case "PlanWrapper/ExistingPlanPreserved/EvaluationValid=$valid" {
        param($valid)
        $f = New-Fixture
        Write-ApprovedAssets $f
        $before = Get-Snapshot $f
        Invoke-Isolated {
            param($state)
            $version = if ($valid) { '1.2.3' } else { '1.2.4' }
            Add-Evaluation $state $f (@{ Properties = @{ PackageVersion = $version; PackageId = 'Owner.Library' } } | ConvertTo-Json)
            $message = if ($valid) { 'A release plan already exists; inspect the original attempt.' } else { 'Tag and evaluated project version differ.' }
            Assert-Throws -Message $message -Action { Invoke-PlanWrapper $f }
            Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
        }
    } $valid
}
Add-Case 'PlanWrapper/IndependentOfCallerWorkingDirectory' {
    $f = New-Fixture
    $cwd = (Get-Location).Path
    Invoke-Isolated {
        param($state)
        Set-Location -LiteralPath (New-OwnedDirectory)
        Add-Evaluation $state $f '{"Properties":{"PackageVersion":"1.2.3","PackageId":"Owner.Library"}}'
        Assert-Equal -Expected 0 -Actual @(Invoke-PlanWrapper $f).Count
        Assert-Equal -Expected $true -Actual ([IO.File]::Exists((Join-Path $f.Directory 'release-plan.json')))
    }
    Assert-Equal -Expected $cwd -Actual (Get-Location).Path
}
Add-Case 'PlanWrapper/MissingChangelogFile' {
    $f = New-Fixture
    [IO.File]::Delete($f.ChangelogPath)
    Invoke-Isolated {
        param($state)
        Add-Evaluation $state $f '{"Properties":{"PackageVersion":"1.2.3","PackageId":"Owner.Library"}}'
        Assert-Throws -Category 'ObjectNotFound' -Action { Invoke-PlanWrapper $f }
        Assert-NoGeneratedAssets $f
    }
}

foreach ($name in $contextNames | Where-Object { $_ -ne 'NUGET_API_KEY' }) {
    foreach ($mode in 'Wrong', 'Unset', 'Empty', 'Case') {
        Add-Case "PublishWrapper/RejectsContext/$name/$mode" {
            param($row)
            $f = New-Fixture
            Write-ApprovedAssets $f
            $before = Get-Snapshot $f
            Invoke-Isolated {
                param($state)
                Set-Context $f
                $value = switch ($row.Mode) {
                    Wrong { 'wrong' }
                    Unset { $null }
                    Empty { '' }
                    Case { [Environment]::GetEnvironmentVariable($row.Name, 'Process').ToUpperInvariant() }
                }
                [Environment]::SetEnvironmentVariable($row.Name, $value, 'Process')
                Assert-Throws -Message 'Publication context does not match the approved release plan.' -Action {
                    & $publishWrapper -ArtifactDirectory $f.Directory -WhatIf
                }
                Assert-Equal -Expected 0 -Actual $state.Calls.Count
                Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
            }
        } @{ Name = $name; Mode = $mode }
    }
}
foreach ($row in @(
    @{ Name = 'Package'; Id = 'ShmuelieSkills.Fixture.Library'; Repository = 'owner/library' },
    @{ Name = 'PackageMixedCase'; Id = 'sHmUeLiEsKiLlS.fIxTuRe.Library'; Repository = 'owner/library' },
    @{ Name = 'Repository'; Id = 'Owner.Library'; Repository = 'example/library' },
    @{ Name = 'RepositoryMixedCase'; Id = 'Owner.Library'; Repository = 'eXaMpLe/library' }
)) {
    Add-Case "PublishWrapper/RejectsFictionalSentinel/$($row.Name)" {
        param($row)
        $f = New-Fixture -Id $row.Id -Repository $row.Repository
        Write-ApprovedAssets $f
        Invoke-Isolated {
            param($state)
            Set-Context $f
            Assert-Throws -Message 'Replace the fictional fixture identity before configuring publication.' -Action {
                & $publishWrapper -ArtifactDirectory $f.Directory -WhatIf
            }
            Assert-Equal -Expected 0 -Actual $state.Calls.Count
        }
    } $row
}
foreach ($mode in 'Hash', 'Schema', 'Flag') {
    Add-Case "PublishWrapper/ValidatesArtifactsBeforeContext/$mode" {
        param($mode)
        $f = New-Fixture
        $message = switch ($mode) {
            Hash { $f.Plan.Artifacts[0].Sha256 = '0' * 64; "Artifact checksum mismatch: $($f.Names[0])" }
            Schema { $f.Plan.SchemaVersion = 2; 'Unsupported release plan schema.' }
            Flag { $f.Plan.Prerelease = 'false'; 'Invalid prerelease flag.' }
        }
        Write-ApprovedAssets $f
        Invoke-Isolated {
            param($state)
            Set-Context $f
            $env:GITHUB_REPOSITORY = 'wrong/repo'
            Assert-Throws -Message $message -Action { & $publishWrapper -ArtifactDirectory $f.Directory -WhatIf }
            Assert-Equal -Expected 0 -Actual $state.Calls.Count
        }
    } $mode
}
foreach ($index in 0..4) {
    Add-Case "PublishWrapper/RequiresEveryLocalAsset/$index" {
        param($index)
        $f = New-Fixture
        Write-ApprovedAssets $f
        $names = @($f.Names) + @('release-plan.json', 'release-notes.md', 'SHA256SUMS')
        [IO.File]::Delete((Join-Path $f.Directory $names[$index]))
        Invoke-Isolated {
            param($state)
            Set-Context $f
            Assert-Throws -Category 'ObjectNotFound' -Action { & $publishWrapper -ArtifactDirectory $f.Directory -WhatIf }
            Assert-Equal -Expected 0 -Actual $state.Calls.Count
        }
    } $index
}
Add-Case 'PublishWrapper/RejectsMalformedPlanJson' {
    $f = New-Fixture
    Write-ApprovedAssets $f
    [IO.File]::WriteAllText((Join-Path $f.Directory 'release-plan.json'), '{bad')
    Invoke-Isolated {
        param($state)
        Set-Context $f
        Assert-Throws -Category 'NotSpecified' -Action { & $publishWrapper -ArtifactDirectory $f.Directory -WhatIf }
        Assert-Equal -Expected 0 -Actual $state.Calls.Count
    }
}
foreach ($version in '1.2.3', '1.2.3-rc.10') {
    Add-Case "PublishWrapper/WhatIfNeedsNoKeyAndNeverTransports/$version" {
        param($version)
        $f = New-Fixture -Version $version
        Write-ApprovedAssets $f
        $before = Get-Snapshot $f
        Invoke-Isolated {
            param($state)
            Set-Context $f
            Assert-Equal -Expected 0 -Actual @(& $publishWrapper -ArtifactDirectory $f.Directory -WhatIf).Count
            Assert-Equal -Expected 0 -Actual $state.Calls.Count
            Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
        }
    } $version
}
foreach ($row in @(@{ Name = 'Unset'; Value = $null }, @{ Name = 'Empty'; Value = '' }, @{ Name = 'Whitespace'; Value = '  ' })) {
    Add-Case "PublishWrapper/RequiresKeyBeforeTransport/$($row.Name)" {
        param($row)
        $f = New-Fixture
        Write-ApprovedAssets $f
        Invoke-Isolated {
            param($state)
            Set-Context $f
            [Environment]::SetEnvironmentVariable('NUGET_API_KEY', $row.Value, 'Process')
            Assert-Throws -Message 'A short-lived NuGet API key (or explicitly configured alternative) is required.' -Action {
                & $publishWrapper -ArtifactDirectory $f.Directory -Confirm:$false
            }
            Assert-Equal -Expected 0 -Actual $state.Calls.Count
        }
    } $row
}

# File links are optional only when the host denies link creation. Test-owned targets stay in scratch.
foreach ($api in 'Artifacts', 'PublishWrapper') {
    $indices = if ($api -eq 'Artifacts') { @(0, 1) } else { @(0..4) }
    foreach ($index in $indices) {
        Add-Case "$api/RejectsLocalAssetLinks/$index" {
            param($row)
            $f = New-Fixture
            Write-ApprovedAssets $f
            $names = @($f.Names) + @('release-plan.json', 'release-notes.md', 'SHA256SUMS')
            $path = Join-Path $f.Directory $names[$row.Index]
            $target = Join-Path $f.Root 'link-target.bin'
            [IO.File]::Move($path, $target)
            try { $null = New-Item -ItemType SymbolicLink -Path $path -Target $target -ErrorAction Stop }
            catch {
                if ($_.Exception -is [UnauthorizedAccessException] -or $_.CategoryInfo.Category -eq 'PermissionDenied') {
                    throw [PlatformNotSupportedException]::new("SKIP: file-link capability denied: $($_.Exception.Message)")
                }
                throw
            }
            if ($row.Api -eq 'Artifacts') {
                Assert-Throws -Message 'Artifact links are not allowed.' -Action { Assert-ReleaseArtifacts $f.Plan $f.Directory }
            } else {
                Invoke-Isolated {
                    param($state)
                    Set-Context $f
                    $message = if ($row.Index -lt 2) { 'Artifact links are not allowed.' } else { 'Asset links are not allowed.' }
                    Assert-Throws -Message $message -Action { & $publishWrapper -ArtifactDirectory $f.Directory -WhatIf }
                    Assert-Equal -Expected 0 -Actual $state.Calls.Count
                }
            }
        } @{ Api = $api; Index = $index }
    }
}

function Add-RemoteTagResponse {
    param($State, $Fixture, [int]$Depth = 0, [switch]$WrongTarget)
    $p = $Fixture.Plan
    $arguments = @('api', "repos/$($p.Repository)/git/ref/tags/$($p.Tag)")
    for ($level = 0; $level -le $Depth; $level++) {
        $target = if ($level -lt $Depth) {
            @{ type = 'tag'; sha = ($level + 1).ToString('x40') }
        } else {
            @{ type = 'commit'; sha = $(if ($WrongTarget) { 'f' * 40 } else { $p.Commit }) }
        }
        Add-NativeResponse $State 'gh' $arguments (@{ object = $target } | ConvertTo-Json)
        $arguments = @('api', "repos/$($p.Repository)/git/tags/$($target.sha)")
    }
}

function Assert-PublicationWrites {
    param($State, [AllowEmptyCollection()][string[]]$Expected)
    $writes = @(
        foreach ($call in $State.Calls) {
            if ($call.Command -ceq 'gh' -and $call.Arguments[0] -ceq 'release') {
                switch -CaseSensitive ($call.Arguments[1]) {
                    create { 'CreateDraft' }
                    upload { 'UploadAssets' }
                    edit { 'PublishRelease' }
                }
            } elseif ($call.Command -ceq 'dotnet' -and $call.Arguments[0] -ceq 'nuget') {
                if ($call.Arguments[2].EndsWith('.snupkg', [StringComparison]::Ordinal)) { 'PushSymbols' }
                else { 'PushPackage' }
            }
        }
    )
    Assert-Sequence -Expected $Expected -Actual $writes
}

function Add-PublicationResponses {
    param($State, $Fixture, [string]$Failure = '', [int]$TagDepth = 0,
        [switch]$Backport, [switch]$ExistingVersions)
    $p = $Fixture.Plan
    $directory = $Fixture.Directory
    $tagArgs = @('api', "repos/$($p.Repository)/git/ref/tags/$($p.Tag)")
    if ($Failure -eq 'Gh') {
        Add-NativeResponse $State 'gh' $tagArgs 'injected-gh' 17
        return
    }
    Add-RemoteTagResponse $State $Fixture -Depth $TagDepth -WrongTarget:($Failure -eq 'WrongTag')
    if ($Failure -eq 'WrongTag') { return }
    $firstPage = '[{"tag_name":"v1.1.0","draft":false,"prerelease":false}]'
    $secondPage = if ($Failure -in 'ExistingDraft', 'ExistingRelease') {
        '[' + (@{ tag_name = $p.Tag; draft = ($Failure -eq 'ExistingDraft'); prerelease = $p.Prerelease } | ConvertTo-Json -Compress) + ']'
    } elseif ($Backport) {
        '[{"tag_name":"v2.0.0","draft":false,"prerelease":false}]'
    } else { '[]' }
    Add-NativeResponse $State 'gh' @('api', '--paginate', '--slurp', "repos/$($p.Repository)/releases?per_page=100") "[$firstPage,$secondPage]"
    if ($Failure -in 'ExistingDraft', 'ExistingRelease') { return }
    $statusCode = switch ($Failure) {
        NugetExisting { 200 }
        NugetUnauthorized { 401 }
        NugetThrottled { 429 }
        NugetUnavailable { 503 }
        default { if ($ExistingVersions) { 200 } else { 404 } }
    }
    $versions = if ($Failure -eq 'NugetExisting') { @('1.0.0', $p.Version, '2.0.0') } else { @('1.0.0', '1.1.0') }
    $response = [pscustomobject]@{ StatusCode = $statusCode; Content = (@{ versions = $versions } | ConvertTo-Json) }
    Add-NativeResponse $State 'web' @('-Uri', 'https://api.nuget.org/v3-flatcontainer/owner.library/index.json', '-SkipHttpErrorCheck', '-TimeoutSec', '30') $response
    if ($Failure -in 'NugetExisting', 'NugetUnauthorized', 'NugetThrottled', 'NugetUnavailable') { return }
    Add-RemoteTagResponse $State $Fixture -Depth $TagDepth -WrongTarget:($Failure -eq 'TagChangedBeforeDraft')
    if ($Failure -eq 'TagChangedBeforeDraft') { return }
    $exitCode = if ($Failure -eq 'CreateDraft') { 17 } else { 0 }
    Add-NativeResponse $State 'gh' @('release', 'create', $p.Tag, '--repo', $p.Repository, '--verify-tag', '--draft', '--title', $p.Tag, '--notes-file', (Join-Path $directory 'release-notes.md')) 'draft-create response' $exitCode
    if ($exitCode) { return }
    $assetNames = @($Fixture.Names) + @('release-plan.json', 'release-notes.md', 'SHA256SUMS')
    $paths = @($assetNames | ForEach-Object { Join-Path $directory $_ })
    $exitCode = if ($Failure -eq 'UploadAssets') { 17 } else { 0 }
    Add-NativeResponse $State 'gh' (@('release', 'upload', $p.Tag, '--repo', $p.Repository) + $paths) 'asset-upload response' $exitCode
    if ($exitCode) { return }
    foreach ($name in $assetNames) {
        $corrupt = $Failure -eq 'Download'
        Add-NativeResponse $State 'gh' @('release', 'download', $p.Tag, '--repo', $p.Repository, '--pattern', $name, '--dir') `
            -DynamicDownload -Source (Join-Path $directory $name) -Corrupt:$corrupt
        if ($corrupt) { return }
    }
    foreach ($index in 0, 1) {
        $stage = if ($index -eq 0) { 'PushPackage' } else { 'PushSymbols' }
        Add-RemoteTagResponse $State $Fixture -Depth $TagDepth -WrongTarget:($Failure -eq "TagChangedBefore$stage")
        if ($Failure -eq "TagChangedBefore$stage") { return }
        $exitCode = if ($Failure -eq $stage) { 23 } else { 0 }
        $pushArguments = @('nuget', 'push', $paths[$index], '--source', 'https://api.nuget.org/v3/index.json', '--api-key', 'fake-test-only')
        if ($index -eq 0) { $pushArguments += '--no-symbols' }
        Add-NativeResponse $State 'dotnet' $pushArguments 'native noise' $exitCode
        if ($exitCode) { return }
    }
    Add-RemoteTagResponse $State $Fixture -Depth $TagDepth -WrongTarget:($Failure -eq 'TagChangedBeforeFinalization')
    if ($Failure -eq 'TagChangedBeforeFinalization') { return }
    $exitCode = if ($Failure -eq 'PublishRelease') { 17 } else { 0 }
    Add-NativeResponse $State 'gh' @('release', 'edit', $p.Tag, '--repo', $p.Repository, '--draft=false', "--prerelease=$($p.Prerelease.ToString().ToLowerInvariant())", "--latest=$((-not $p.Prerelease -and -not $Backport).ToString().ToLowerInvariant())") 'finalization response' $exitCode
    if ($exitCode) { return }
    $remote = @{ tagName = $p.Tag; isDraft = $false; isPrerelease = $p.Prerelease; assets = @($assetNames | ForEach-Object { @{ name = $_ } }) }
    switch ($Failure) {
        FinalDraft { $remote.isDraft = $true }
        FinalPrerelease { $remote.isPrerelease = -not $p.Prerelease }
        FinalTag { $remote.tagName = 'v1.2.4' }
        FinalMissingAsset { $remote.assets = @($remote.assets | Select-Object -Skip 1) }
        FinalExtraAsset { $remote.assets += @{ name = 'unexpected.txt' } }
        FinalDuplicateAsset { $remote.assets += @{ name = $assetNames[0] } }
    }
    $exitCode = if ($Failure -eq 'ViewRelease') { 17 } else { 0 }
    $output = if ($exitCode) { 'release-view response' } else { $remote | ConvertTo-Json -Depth 5 }
    Add-NativeResponse $State 'gh' @('release', 'view', $p.Tag, '--repo', $p.Repository, '--json', 'tagName,isDraft,isPrerelease,assets') $output $exitCode
}

foreach ($row in @(
    @{ Name = 'Stable'; Version = '1.2.3'; Depth = 0; Backport = $false; ExistingVersions = $false; Calls = 18 },
    @{ Name = 'Prerelease'; Version = '1.2.3-rc.10'; Depth = 0; Backport = $false; ExistingVersions = $false; Calls = 18 },
    @{ Name = 'AnnotatedTag'; Version = '1.2.3'; Depth = 1; Backport = $false; ExistingVersions = $false; Calls = 23 },
    @{ Name = 'NestedAnnotatedTag'; Version = '1.2.3'; Depth = 2; Backport = $false; ExistingVersions = $false; Calls = 28 },
    @{ Name = 'BackportNotLatest'; Version = '1.2.3'; Depth = 0; Backport = $true; ExistingVersions = $false; Calls = 18 },
    @{ Name = 'OtherNugetVersionsExist'; Version = '1.2.3'; Depth = 0; Backport = $false; ExistingVersions = $true; Calls = 18 }
)) {
    Add-Case "PublishWrapper/FullyFakedHappyPath/$($row.Name)" {
        param($row)
        $f = New-Fixture -Version $row.Version
        Write-ApprovedAssets $f
        $before = Get-Snapshot $f
        Invoke-Isolated {
            param($state)
            Set-Context $f
            $env:NUGET_API_KEY = 'fake-test-only'
            Add-PublicationResponses $state $f -TagDepth $row.Depth -Backport:$row.Backport -ExistingVersions:$row.ExistingVersions
            $result = @(& $publishWrapper -ArtifactDirectory $f.Directory -Confirm:$false)
            Assert-Equal -Expected 1 -Actual $result.Count
            Assert-Equal -Expected 'Published' -Actual $result[0].Status
            Assert-Sequence -Expected $steps -Actual $result[0].Completed
            Assert-Equal -Expected $row.Calls -Actual $state.Calls.Count
            Assert-PublicationWrites $state @('CreateDraft', 'UploadAssets', 'PushPackage', 'PushSymbols', 'PublishRelease')
            $pushes = @($state.Calls | Where-Object Command -CEQ 'dotnet')
            Assert-Equal -Expected 2 -Actual $pushes.Count
            Assert-Equal -Expected $true -Actual ($pushes[0].Arguments -ccontains '--no-symbols')
            Assert-Equal -Expected $false -Actual ($pushes[1].Arguments -ccontains '--no-symbols')
            Assert-Equal -Expected (Join-Path $f.Directory $f.Names[1]) -Actual $pushes[1].Arguments[2]
            Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
        }
    } $row
}
$draftWrite = @('CreateDraft')
$assetWrites = @('CreateDraft', 'UploadAssets')
$packageWrites = @('CreateDraft', 'UploadAssets', 'PushPackage')
$symbolWrites = @('CreateDraft', 'UploadAssets', 'PushPackage', 'PushSymbols')
$allWrites = @('CreateDraft', 'UploadAssets', 'PushPackage', 'PushSymbols', 'PublishRelease')
$wrongTag = 'Remote tag does not resolve to the validated commit.'
$wrongRelease = 'Published release state did not match the plan.'
$wrongAssets = 'Published asset set did not match the plan.'
foreach ($row in @(
    @{ Name = 'Gh'; Failure = 'Gh'; Step = 'Preflight'; Calls = 1; Writes = @(); Error = 'GitHub operation failed (exit 17): injected-gh' },
    @{ Name = 'ExistingDraft'; Failure = 'ExistingDraft'; Step = 'Preflight'; Calls = 2; Writes = @(); Error = 'Release/draft already exists; use explicit recovery.' },
    @{ Name = 'ExistingRelease'; Failure = 'ExistingRelease'; Step = 'Preflight'; Calls = 2; Writes = @(); Error = 'Release/draft already exists; use explicit recovery.' },
    @{ Name = 'NugetExisting'; Failure = 'NugetExisting'; Step = 'Preflight'; Calls = 3; Writes = @(); Error = 'NuGet version already exists; inspect the previous attempt.' },
    @{ Name = 'NugetUnauthorized'; Failure = 'NugetUnauthorized'; Step = 'Preflight'; Calls = 3; Writes = @(); Error = 'NuGet preflight failed: HTTP 401.' },
    @{ Name = 'NugetThrottled'; Failure = 'NugetThrottled'; Step = 'Preflight'; Calls = 3; Writes = @(); Error = 'NuGet preflight failed: HTTP 429.' },
    @{ Name = 'NugetUnavailable'; Failure = 'NugetUnavailable'; Step = 'Preflight'; Calls = 3; Writes = @(); Error = 'NuGet preflight failed: HTTP 503.' },
    @{ Name = 'WrongTag'; Failure = 'WrongTag'; Step = 'Preflight'; Calls = 1; Writes = @(); Error = $wrongTag },
    @{ Name = 'AnnotatedWrongTarget'; Failure = 'WrongTag'; Depth = 2; Step = 'Preflight'; Calls = 3; Writes = @(); Error = $wrongTag },
    @{ Name = 'TagChangedBeforeDraft'; Failure = 'TagChangedBeforeDraft'; Step = 'CreateDraft'; Calls = 4; Writes = @(); Error = $wrongTag },
    @{ Name = 'CreateDraft'; Failure = 'CreateDraft'; Step = 'CreateDraft'; Calls = 5; Writes = $draftWrite; Error = 'GitHub operation failed (exit 17): draft-create response' },
    @{ Name = 'UploadAssets'; Failure = 'UploadAssets'; Step = 'UploadAssets'; Calls = 6; Writes = $assetWrites; Error = 'GitHub operation failed (exit 17): asset-upload response' },
    @{ Name = 'Download'; Failure = 'Download'; Step = 'VerifyAssets'; Calls = 7; Writes = $assetWrites; Error = 'Uploaded asset differs: Owner.Library.1.2.3.nupkg' },
    @{ Name = 'TagChangedAfterDraftBeforeNuget'; Failure = 'TagChangedBeforePushPackage'; Step = 'PushPackage'; Calls = 12; Writes = $assetWrites; Error = $wrongTag },
    @{ Name = 'PushPackage'; Failure = 'PushPackage'; Step = 'PushPackage'; Calls = 13; Writes = $packageWrites; Error = 'PushPackage failed (exit 23); no duplicate-skipping or rollback attempted.' },
    @{ Name = 'TagChangedBeforeSymbols'; Failure = 'TagChangedBeforePushSymbols'; Step = 'PushSymbols'; Calls = 14; Writes = $packageWrites; Error = $wrongTag },
    @{ Name = 'PushSymbols'; Failure = 'PushSymbols'; Step = 'PushSymbols'; Calls = 15; Writes = $symbolWrites; Error = 'PushSymbols failed (exit 23); no duplicate-skipping or rollback attempted.' },
    @{ Name = 'TagChangedBeforeFinalization'; Failure = 'TagChangedBeforeFinalization'; Step = 'PublishRelease'; Calls = 16; Writes = $symbolWrites; Error = $wrongTag },
    @{ Name = 'PublishRelease'; Failure = 'PublishRelease'; Step = 'PublishRelease'; Calls = 17; Writes = $allWrites; Error = 'GitHub operation failed (exit 17): finalization response' },
    @{ Name = 'ViewRelease'; Failure = 'ViewRelease'; Step = 'VerifyRelease'; Calls = 18; Writes = $allWrites; Error = 'GitHub operation failed (exit 17): release-view response' },
    @{ Name = 'FinalDraft'; Failure = 'FinalDraft'; Step = 'VerifyRelease'; Calls = 18; Writes = $allWrites; Error = $wrongRelease },
    @{ Name = 'FinalPrerelease'; Failure = 'FinalPrerelease'; Step = 'VerifyRelease'; Calls = 18; Writes = $allWrites; Error = $wrongRelease },
    @{ Name = 'FinalTag'; Failure = 'FinalTag'; Step = 'VerifyRelease'; Calls = 18; Writes = $allWrites; Error = $wrongRelease },
    @{ Name = 'FinalMissingAsset'; Failure = 'FinalMissingAsset'; Step = 'VerifyRelease'; Calls = 18; Writes = $allWrites; Error = $wrongAssets },
    @{ Name = 'FinalExtraAsset'; Failure = 'FinalExtraAsset'; Step = 'VerifyRelease'; Calls = 18; Writes = $allWrites; Error = $wrongAssets },
    @{ Name = 'FinalDuplicateAsset'; Failure = 'FinalDuplicateAsset'; Step = 'VerifyRelease'; Calls = 18; Writes = $allWrites; Error = $wrongAssets }
)) {
    Add-Case "PublishWrapper/StopsAtExactBoundary/$($row.Name)" {
        param($row)
        $f = New-Fixture
        Write-ApprovedAssets $f
        $before = Get-Snapshot $f
        Invoke-Isolated {
            param($state)
            Set-Context $f
            $env:NUGET_API_KEY = 'fake-test-only'
            $depth = if ($row.ContainsKey('Depth')) { $row.Depth } else { 0 }
            Add-PublicationResponses $state $f $row.Failure -TagDepth $depth
            $index = [array]::IndexOf($steps, $row.Step)
            $completed = @($steps | Select-Object -First $index)
            Assert-Throws -Message "Release failed at $($row.Step). Completed: $($completed -join ', '). Keep original artifacts and draft for explicit recovery. $($row.Error)" -Action {
                & $publishWrapper -ArtifactDirectory $f.Directory -Confirm:$false
            }
            Assert-Equal -Expected $row.Calls -Actual $state.Calls.Count
            Assert-PublicationWrites $state $row.Writes
            Assert-Sequence -Expected $before -Actual (Get-Snapshot $f)
        }
    } $row
}

$passed = 0
$failed = 0
$skipped = 0
Write-Host "Registered $($cases.Count) no-network cases. Scratch: $work"
foreach ($case in $cases) {
    try {
        $output = @(& $case.Action $case.Data)
        Assert-Equal -Expected 0 -Actual $output.Count
        $passed++
        Write-Host "PASS $($case.Name)"
    } catch {
        if ($_.Exception -is [PlatformNotSupportedException] -and $_.Exception.Message.StartsWith('SKIP:')) {
            $skipped++
            Write-Host "SKIP $($case.Name): $($_.Exception.Message)"
        } else {
            $failed++
            Write-Host "FAIL $($case.Name): $($_.Exception.Message)"
            Write-Host $_.ScriptStackTrace
        }
    }
}
foreach ($group in $cases | Group-Object { ($_.Name -split '/')[0] } | Sort-Object Name) {
    Write-Host "GROUP $($group.Name): $($group.Count)"
}
Write-Host "Registered=$($cases.Count); Executed=$($passed + $failed + $skipped); Passed=$passed; Failed=$failed; Skipped=$skipped"
if ($failed) {
    Write-Host "Failure fixtures retained at $work"
    exit 1
}
# Only this invocation's GUID child is removed; never remove ScratchRoot.
Remove-Item -LiteralPath $work -Recurse -Force
