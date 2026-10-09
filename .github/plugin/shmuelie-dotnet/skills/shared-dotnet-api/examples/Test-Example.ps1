[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$checks = 0
$scratch = Join-Path $PSScriptRoot ('.scratch-' + [guid]::NewGuid().ToString('N'))
$cliProject = Join-Path $PSScriptRoot 'Synthetic.Cli\Synthetic.Cli.csproj'
$cliDll = Join-Path $PSScriptRoot 'Synthetic.Cli\bin\Release\net8.0\Synthetic.Cli.dll'
$coreDll = Join-Path $PSScriptRoot 'Synthetic.Core\bin\Release\net8.0\Synthetic.Core.dll'

function Assert([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw "FAILED: $Message" }
    $script:checks++
}

function Invoke-ExampleCli([string[]] $Arguments) {
    $start = [System.Diagnostics.ProcessStartInfo]::new('dotnet')
    $start.ArgumentList.Add($cliDll)
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        return [pscustomobject]@{ Code = $process.ExitCode; Out = $stdout.Trim(); Err = $stderr.Trim() }
    }
    finally { $process.Dispose() }
}

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    dotnet build $cliProject --configuration Release --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { throw 'Example build failed.' }

    Import-Module (Join-Path $PSScriptRoot 'Synthetic.PowerShell\Synthetic.PowerShell.psm1') `
        -ArgumentList $coreDll -Force
    Add-Type -Path $cliDll
    $file = Join-Path $scratch 'items.json'
    $service = [Synthetic.Core.ItemService]::new([Synthetic.Core.JsonFileItemStore]::new($file))
    $none = [System.Threading.CancellationToken]::None

    Assert (($service.ListAsync($none).GetAwaiter().GetResult()).Count -eq 0) 'core empty read'
    $first = $service.AddAsync(' alpha ', $none).GetAwaiter().GetResult()
    Assert ($first.Name -ceq 'alpha') 'core trims name'
    Assert ((@($service.ListAsync($none).GetAwaiter().GetResult())).Count -eq 1) 'core mutation persisted'
    $conflictTask = $service.AddAsync('ALPHA', $none)
    try {
        $null = ([System.IAsyncResult]$conflictTask).AsyncWaitHandle.WaitOne()
        Assert ($conflictTask.Exception.GetBaseException() -is
            [Synthetic.Core.ItemAlreadyExistsException]) 'core conflict is case insensitive'
    }
    finally { $conflictTask.Dispose() }
    $cancelCore = [System.Threading.CancellationTokenSource]::new()
    try {
        $cancelCore.Cancel()
        Assert ($service.ListAsync($cancelCore.Token).IsCanceled) 'core propagates cancellation'
    }
    finally { $cancelCore.Dispose() }
    Assert ((@(Get-SyntheticItem -Path $file)).Count -eq 1) 'cmdlet reads core state'
    Assert ((@([pscustomobject]@{ Path = $file } | Get-SyntheticItem))[0].Name -ceq 'alpha') `
        'read cmdlet binds pipeline property'

    $before = Get-Content $file -Raw
    $preview = @('not-added' | Add-SyntheticItem -Path $file -WhatIf)
    Assert ($preview.Count -eq 0 -and (Get-Content $file -Raw) -ceq $before) `
        'WhatIf has no output or side effect'

    $fromPipeline = @('beta', 'gamma' | Add-SyntheticItem -Path $file)
    Assert ($fromPipeline.Count -eq 2 -and $fromPipeline[0].Name -ceq 'beta' `
        -and $fromPipeline[1].Name -ceq 'gamma') 'mutation cmdlet binds pipeline values'
    $coreNames = @($service.ListAsync($none).GetAwaiter().GetResult() | ForEach-Object Name)
    $listed = Invoke-ExampleCli @('list', '--file', $file, '--json')
    Assert ($listed.Code -eq 0 -and -not $listed.Err `
        -and (@($listed.Out | ConvertFrom-Json).Name -join ',') -ceq ($coreNames -join ',')) `
        'CLI JSON read matches core and cmdlet output'
    $text = Invoke-ExampleCli @('list', '--file', $file)
    Assert ($text.Code -eq 0 -and $text.Out -match 'alpha' -and $text.Out -match 'gamma') `
        'CLI human-readable read'
    $added = Invoke-ExampleCli @('add', '--file', $file, '--name', 'delta', '--json')
    Assert ($added.Code -eq 0 -and ($added.Out | ConvertFrom-Json).Name -ceq 'delta' `
        -and (@(Get-SyntheticItem -Path $file)).Count -eq 4) `
        'CLI JSON mutation visible from cmdlet'
    $addedText = Invoke-ExampleCli @('add', '--file', $file, '--name', 'epsilon')
    Assert ($addedText.Code -eq 0 -and $addedText.Out -ceq 'Added: epsilon') `
        'CLI human-readable mutation'

    try {
        $null = $service.AddAsync('  ', $none).GetAwaiter().GetResult()
        throw 'Expected core validation.'
    }
    catch [System.ArgumentException] {
        Assert ($_.Exception.ParamName -eq 'name') 'core validates name once for both hosts'
    }
    $invalid = Invoke-ExampleCli @('add', '--file', $file, '--name', '  ')
    Assert ($invalid.Code -eq 2 -and $invalid.Err -match '^Invalid input' `
        -and -not $invalid.Out) 'CLI validation exit 2 without partial stdout'
    $duplicate = Invoke-ExampleCli @('add', '--file', $file, '--name', 'ALPHA')
    Assert ($duplicate.Code -eq 3 -and $duplicate.Err -ceq 'Item already exists.' `
        -and -not $duplicate.Out) 'CLI conflict exit 3'

    $errors = @()
    $continuing = @('zeta', 'ALPHA', 'eta' | Add-SyntheticItem -Path $file `
        -ErrorAction Continue -ErrorVariable +errors 2>$null)
    Assert ($continuing.Count -eq 2 -and $continuing[1].Name -ceq 'eta' `
        -and $errors.Count -eq 1 -and $errors[0].CategoryInfo.Category -eq 'ResourceExists') `
        'cmdlet conflict is non-terminating and pipeline continues'
    $errors = @()
    $null = ' ' | Add-SyntheticItem -Path $file -ErrorAction Continue `
        -ErrorVariable +errors 2>$null
    Assert ($errors.Count -eq 1 -and $errors[0].CategoryInfo.Category -eq 'InvalidArgument') `
        'cmdlet maps core validation to non-terminating error'
    try {
        $null = 'ALPHA' | Add-SyntheticItem -Path $file -ErrorAction Stop
        throw 'Expected ErrorAction Stop.'
    }
    catch {
        Assert ($_.FullyQualifiedErrorId -match 'ItemAlreadyExists') `
            'caller can promote mapped error with ErrorAction Stop'
    }

    $badPath = Join-Path $scratch 'missing\items.json'
    $failed = Invoke-ExampleCli @('add', '--file', $badPath, '--name', 'x')
    Assert ($failed.Code -eq 1 -and $failed.Err -ceq 'Store operation failed.' `
        -and -not $failed.Out) 'CLI store error exit 1 without partial stdout or path leak'
    try {
        $null = Add-SyntheticItem -Path $badPath -Name x
        throw 'Expected terminating store error.'
    }
    catch {
        Assert ($_.FullyQualifiedErrorId -match 'ItemWriteFailed') `
            'cmdlet store error terminates with mapped ID'
    }
    $corrupt = Join-Path $scratch 'corrupt.json'
    Set-Content $corrupt 'not-json'
    $readError = Invoke-ExampleCli @('list', '--file', $corrupt, '--json')
    Assert ($readError.Code -eq 1 -and -not $readError.Out) 'CLI corrupt store exit 1'
    try {
        $null = Get-SyntheticItem -Path $corrupt
        throw 'Expected terminating read error.'
    }
    catch {
        Assert ($_.FullyQualifiedErrorId -match 'ItemReadFailed') `
            'cmdlet corrupt store terminates with mapped ID'
    }

    $cancel = [System.Threading.CancellationTokenSource]::new()
    try {
        $cancel.Cancel()
        $output = [System.IO.StringWriter]::new()
        $cancelError = [System.IO.StringWriter]::new()
        try {
            $code = [Cli]::RunAsync(
                [string[]]@('add', '--file', $file, '--name', 'cancelled'),
                $output, $cancelError, $cancel.Token).GetAwaiter().GetResult()
            Assert ($code -eq 130 -and $cancelError.ToString().Trim() -ceq 'Cancelled.' `
                -and -not $output.ToString() -and
                (@(Get-SyntheticItem -Path $file | Where-Object Name -eq 'cancelled')).Count -eq 0) `
                'CLI injected cancellation exits 130 with no mutation or stdout'
        }
        finally { $output.Dispose(); $cancelError.Dispose() }
    }
    finally { $cancel.Dispose() }
    Write-Host "Passed: $checks assertions (core, cmdlets, CLI)."
}
finally {
    Remove-Module Synthetic.PowerShell -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
