<#
.SYNOPSIS
    Hook launcher that forwards an agent hook payload to the C# toast renderer.
.DESCRIPTION
    Invoked by the plugin hook definitions (copilot-hooks.json / hooks.json) on a
    notification-worthy agent event. Reads the hook payload (JSON) from stdin and
    launches Show-CopilotToast.cs via `dotnet run` **fire-and-forget**, so the
    agent session is never blocked by toast rendering or the first-run compile.

    Resolves the renderer relative to this script, so it works regardless of where
    the plugin is installed. No-ops silently if dotnet or the renderer is missing.
.NOTES
    Set COPILOT_TOAST_DEBUG=1 to have the renderer log its decisions to
    %TEMP%\copilot-toast-debug\toast.log. COPILOT_TOAST_ICON may optionally point
    to a user-provided .ico file for the toast header.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

try {
    $payload = [Console]::In.ReadToEnd()

    $renderer = Join-Path $PSScriptRoot 'Show-CopilotToast.cs'
    if (-not (Test-Path -LiteralPath $renderer)) { return }
    if (-not (Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue)) { return }

    # Stage the payload to a temp file so it can be piped to a detached process.
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "shmuelie-copilot-toast-$PID-$([guid]::NewGuid().ToString('N')).json"
    [System.IO.File]::WriteAllText($tmp, $payload)

    # Fire-and-forget through a detached child that guarantees payload cleanup
    # even when dotnet fails before the renderer starts.
    $escapedRenderer = $renderer.Replace("'", "''")
    $escapedPayload = $tmp.Replace("'", "''")
    $childScript = @"
try {
    & dotnet run --file '$escapedRenderer' -- --payload-file '$escapedPayload'
} finally {
    Remove-Item -LiteralPath '$escapedPayload' -Force -ErrorAction SilentlyContinue
}
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childScript))
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded) `
        -WindowStyle Hidden | Out-Null
} catch {
    if ($tmp -and (Test-Path -LiteralPath $tmp)) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
    # A toast must never break the agent session.
}
