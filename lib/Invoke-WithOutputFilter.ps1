# .SYNOPSIS
# Runs a command, filtering its output through caller-supplied scriptblocks.
#
# All output objects are wrapped in a uniform protocol before ProcessLine sees them:
#
#   .line      — plain text (string); ANSI escape codes stripped
#   .object    — original object (preserves type, ANSI codes, MessageData, etc.)
#   .noNewLine — $true when the item came from Write-Host -NoNewLine (allows callers to
#                buffer partial lines and emit combined output once the full line arrives)
#
# Streams captured by default: stdout (1) and stderr (2), merged into a single ordered stream.
# To capture Write-Host / stream 6, redirect it inside the Command block:
#   -Command { myScript 6>&1 2>&1 }
# ProcessLine can branch on .object type if needed.
#
# .PARAMETER Command
# The scriptblock to run.
#
# .PARAMETER ProcessLine
# Called for each output object as it arrives. Receives ($line, $state).
# $line is the wrapped item (see protocol above).
# Return a string to emit live to the output stream, or $null to suppress.
#
# .PARAMETER RenderResult
# Called after the command completes (in a finally block — always runs).
# Receives ($state). Return strings to emit as post-run output.
#
# .PARAMETER InitialState
# Optional hashtable used directly as the shared $state object (not cloned).
# Useful when the caller needs to inspect accumulated state after the call.
# If omitted, a fresh hashtable is created internally.
#
# .NOTES
# To aid pattern-matching, .line always has ANSI codes (e.g. coloration) stripped out.
# By contrast, the data in .object has the original data. Whether that has ANSI codes stripped out or not,
# is complicated. 
#    Some ways to preserve that data: 
#    - use tool-specific settings (--color flags, FORCE_COLOR=1)
#    - use in-process 6>&1 capture
#    - use the ConPTY (general solution, complex, Windows-specific)

param(
    [scriptblock] $Command,
    [scriptblock] $ProcessLine,
    [scriptblock] $RenderResult,
    [hashtable]   $InitialState = $null
)

$state           = if ($null -ne $InitialState) { $InitialState } else { @{} }
$state.exception = $null

function prepareItem($item) {
    if ($item -is [System.Management.Automation.InformationRecord]) {
        $msgData = $item.MessageData
        # Duck-type check: handles both live and deserialized HostInformationMessage (from background jobs).
        $isHostInfo = $null -ne ($msgData.PSObject.Properties['Message']) -and
                      $null -ne ($msgData.PSObject.Properties['NoNewLine'])
        if ($isHostInfo) {
            $text      = ($msgData.Message) -replace '\x1B\[[0-9;]*[mGKHFABCDJr]', ''
            $noNewLine = $msgData.NoNewLine
        } else {
            $text      = ("$($item.MessageData)") -replace '\x1B\[[0-9;]*[mGKHFABCDJr]', ''
            $noNewLine = $false
        }
        return [PSCustomObject]@{ line = $text; object = $item; noNewLine = $noNewLine }
    }

    if ($item -is [System.Management.Automation.ErrorRecord]) {
        $text = ("$($item.Exception.Message)") -replace '\x1B\[[0-9;]*[mGKHFABCDJr]', ''
        return [PSCustomObject]@{ line = $text; object = $item; noNewLine = $false }
    }

    # Write-Output or any other object: .object is the original.
    $text = ("$item") -replace '\x1B\[[0-9;]*[mGKHFABCDJr]', ''
    return [PSCustomObject]@{ line = $text; object = $item; noNewLine = $false }
}

try {
    & $Command 2>&1 | ForEach-Object {
        $live = & $ProcessLine (prepareItem $_) $state
        if ($null -ne $live) { $live }
    }
} catch {
    $state.exception = $_
    $live = & $ProcessLine (prepareItem $_) $state
    if ($null -ne $live) { $live }
    throw
} finally {
    & $RenderResult $state
}
