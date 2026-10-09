param([Parameter(Mandatory)][string] $CoreAssemblyPath)

Add-Type -Path $CoreAssemblyPath

function Get-SyntheticItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Path,
        [System.Threading.CancellationToken] $CancellationToken =
            [System.Threading.CancellationToken]::None
    )
    process {
        $service = [Synthetic.Core.ItemService]::new(
            [Synthetic.Core.JsonFileItemStore]::new($Path))
        $task = $service.ListAsync($CancellationToken)
        try {
            $null = ([System.IAsyncResult]$task).AsyncWaitHandle.WaitOne()
            if ($task.IsCanceled) {
                throw [System.OperationCanceledException]::new('Item read cancelled.', $CancellationToken)
            }
            $failure = if ($task.IsFaulted) { $task.Exception.GetBaseException() }
            if ($failure -is [System.IO.IOException] -or
                $failure -is [System.UnauthorizedAccessException]) {
                $category = [System.Management.Automation.ErrorCategory]::ReadError
            } elseif ($failure -is [System.Text.Json.JsonException] -or
                      $failure -is [System.IO.InvalidDataException]) {
                $category = [System.Management.Automation.ErrorCategory]::InvalidData
            } elseif ($failure) { throw $failure }
            if ($failure) {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $failure, 'ItemReadFailed', $category, $Path))
            }
            foreach ($item in $task.Result) { Write-Output $item }
        }
        finally { $task.Dispose() }
    }
}

function Add-SyntheticItem {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Name,
        [Parameter(Mandatory)]
        [string] $Path,
        [System.Threading.CancellationToken] $CancellationToken =
            [System.Threading.CancellationToken]::None
    )
    process {
        if (-not $PSCmdlet.ShouldProcess($Name, 'Add synthetic item')) { return }
        $service = [Synthetic.Core.ItemService]::new(
            [Synthetic.Core.JsonFileItemStore]::new($Path))
        $task = $service.AddAsync($Name, $CancellationToken)
        try {
            $null = ([System.IAsyncResult]$task).AsyncWaitHandle.WaitOne()
            if ($task.IsCanceled) {
                throw [System.OperationCanceledException]::new('Item mutation cancelled.', $CancellationToken)
            }
            $failure = if ($task.IsFaulted) { $task.Exception.GetBaseException() }
            if ($failure -is [System.ArgumentException]) {
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $failure, 'InvalidItemName',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument, $Name))
            } elseif ($failure -is [Synthetic.Core.ItemAlreadyExistsException]) {
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $failure, 'ItemAlreadyExists',
                    [System.Management.Automation.ErrorCategory]::ResourceExists, $Name))
            } elseif ($failure -is [System.IO.IOException] -or
                      $failure -is [System.UnauthorizedAccessException] -or
                      $failure -is [System.Text.Json.JsonException] -or
                      $failure -is [System.IO.InvalidDataException]) {
                $category = if ($failure -is [System.IO.IOException] -or
                                $failure -is [System.UnauthorizedAccessException]) {
                    [System.Management.Automation.ErrorCategory]::WriteError
                } else { [System.Management.Automation.ErrorCategory]::InvalidData }
                $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    $failure, 'ItemWriteFailed', $category, $Path))
            } elseif ($failure) { throw $failure }
            if (-not $failure) { Write-Output $task.Result }
        }
        finally { $task.Dispose() }
    }
}

Export-ModuleMember -Function Get-SyntheticItem, Add-SyntheticItem
