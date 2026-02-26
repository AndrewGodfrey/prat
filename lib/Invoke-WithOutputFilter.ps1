# .SYNOPSIS
# Runs a command, filtering its output through caller-supplied scriptblocks.
#
# Stdout and stderr are merged (2>&1) into a single ordered stream. Stderr
# objects arrive as [ErrorRecord]; stdout objects arrive as strings. ProcessLine
# can branch on $line -is [System.Management.Automation.ErrorRecord].
#
# .PARAMETER Command
# The scriptblock to run.
#
# .PARAMETER ProcessLine
# Called for each output object as it arrives. Receives ($line, $state).
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
# .PARAMETER StripAnsi
# When set, non-ErrorRecord objects are stringified and ANSI escape codes are
# stripped before being passed to ProcessLine. 
#
# Without this switch, ProcessLine receives the raw object (string, ErrorRecord, InformationRecord, etc.) and is
# responsible for any stripping.
#
# What this means: Well, it's complicated. See NOTES below.
#
# .NOTES
#
# By default, ANSI codes are preserved in some cases and stripped in others, before this script sees them.
#
# If you want to strip all color from commands:
#
# - Often it already will be. See below for more gory details. But if it isn't:
# - For non-ErrorRecord objects: Adding "-StripAnsi" will strip the ANSI codes.
# - For ErrorRecord objects - the ProcessLine scriptblock will need to manually strip them from ErrorRecord.Message.
#
# If, instead, you wanted to PRESERVE color from commands, here are some options.
#
#   1. Tool-specific --color / --force-color flags
#      Many CLI tools (git, cargo, jest …) accept a flag to force ANSI output
#      even when stdout is piped.  Simplest option where supported.
#
#   2. FORCE_COLOR=1 environment variable
#      Convention followed by much of the Node.js ecosystem.  Set before launch.
#
#   3. In-process capture via 6>&1 (PowerShell scripts only)
#      Call the script in-process with $InformationPreference='SilentlyContinue'
#      and redirect stream 6: { $InformationPreference='SilentlyContinue'; & script 6>&1 2>&1 }
#      Pester's job bakes ANSI codes into InformationRecord.MessageData, so the
#      records arrive with colour intact.  Does not work for external executables
#      (they write to process stdout/stderr, not to PowerShell stream 6).
#
#   4. ConPTY (general solution, complex)
#      Create a Windows pseudo-terminal via the ConPTY API so the child process
#      sees a real terminal (isatty() returns true) and never disables colour.
#      Requires P/Invoke or a NuGet package (e.g. Pty.Net).
#
# Without one of the above, external-process output typically arrives to this script as plain text:
#
# - Most CLI tools never emit ANSI when stdout is not a TTY (they check isatty / 
#   Console.IsOutputRedirected before generating codes).
# - pwsh is unusual: it generates ANSI internally then strips at the rendering  layer 
#   ($PSStyle.OutputRendering auto-selects PlainText for piped stdout).

param(
    [scriptblock] $Command,
    [scriptblock] $ProcessLine,
    [scriptblock] $RenderResult,
    [hashtable]   $InitialState   = $null,
    [switch]      $StripAnsi
)

$state           = if ($null -ne $InitialState) { $InitialState } else { @{} }
$state.exception = $null

function prepareItem($item) {
    # ErrorRecords pass through unchanged: preserves the stderr/stdout distinction
    # for context-buffering, and avoids silently discarding ANSI codes that some
    # tools (rustc, clang, …) write to stderr.  All other objects are stringified
    # and stripped.
    if ($StripAnsi -and $item -isnot [System.Management.Automation.ErrorRecord]) {
        ("$item") -replace '\x1B\[[0-9;]*[mGKHFABCDJr]', ''
    } else {
        $item
    }
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
