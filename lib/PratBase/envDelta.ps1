# .SYNOPSIS
# 
# Functions for manipulating an EnvDelta - a collection of env-var settings that need to be applied.
# You can do the following:
# 
# Invoke-CommandWithEnvDelta:               Run a scriptblock while temporarily applying the EnvDelta.
# Export-EnvDeltaFromInvokedBatchScript:    Execute a batch file, and capture any env-var modifications in a returned EnvDelta.
# 
#
# The purpose of EnvDelta is for use with 'build enlistment' scripts. Many codebases provide an 'enlistment window' or 'build window'
# that you're expected to work from - but many of them add a huge amount of work that is done when you open a new window.
#
# Instead, we can periodically run the update script, capture the resulting EnvDelta, and then later just use the EnvDelta when needed.
#
# Borrows from [Invoke-CmdScript.ps1](http://www.leeholmes.com/blog/2006/05/11/nothing-solves-everything-powershell-and-other-technologies/)
#
# .ASSUMPTIONS
# - Assumes that for an env-var (in env:, or in cmd.exe's 'set' command), 
#   if the variable is equal to an empty string, that's identical to it not being present at all.
# - But internally, this is NOT the case; in $envDelta.apply:
#     If an empty env-var is present: This means that env-var is part of the delta. e.g. it would be emptied on 'apply', and restored to whatever it was before on 'revert'.
#     Otherwise: The env-var is not part of the delta, meaning it should not be touched when this delta is applied/reverted.

# Low-level function: Run a .bat or .cmd script, and capture all the environment variables afterwards.
function runCmdAndCaptureEnv([string] $script, [string] $parameters, [bool] $checkExitCode) {
    $tempFile = [IO.Path]::GetTempFileName()

    # Keys are case-insensitive, which matches how env-vars work.
    $result = @{}
    try {
        cmd /c " `"$script`" $parameters && set > `"$tempFile`" " | Out-Null
        if ($checkExitCode -and ($LastExitCode -ne 0)) { throw "batch script failed: error code: $LastExitCode" }

        foreach ($line in (Get-Content $tempFile)) {
            if ($line -match "^(.*?)=(.*)$") {
                if ($matches[1] -eq "PROMPT") {
                    # Batch files automatically set the PROMPT env-var, which we don't have in the Powershell environment.
                    # So, skip this one.
                    continue 
                }
                $result[$matches[1]] = $matches[2]
            } 
        }  
    } finally {
        Remove-Item $tempFile
    }

    return $result
}

# Capture all the current environment variables.
function captureCurrentEnv() {
    $result = @{}
    foreach ($item in (Get-ChildItem env:)) {
        $result[$item.Name] = $item.Value
    }

    return $result
}

# Given an 'after' and 'before' capture, calculates the 'apply' and 'prev' lists.
# The subtlety is how we handle keys that are only present in one of the two:
#   If in $before but not in $after:    These are not to be modified at all.
#   If in $after but not $before:       These are to be temporarily deleted, and restored after.

function calculateEnvDelta($before, $after, [switch] $MissingInAfterMeansDeletion = $false) {
    $result = @{
        apply = @{}
        prev = @{}
    }

    foreach ($key in $after.Keys) {
        if ($before[$key] -ne $after[$key]) {
            $beforeValue = $before[$key]
            if ($null -eq $beforeValue) { $beforeValue = "" }
            $result.prev[$key]  = $beforeValue
            $result.apply[$key] = $after[$key]
        }
    }

    if ($MissingInAfterMeansDeletion) {
        foreach ($key in $before.Keys) {
            if (!$after.Contains($key)) {
                $result.prev[$key]  = $before[$key]
                $result.apply[$key] = ""
            }
        }
    }

    # Write-DebugValue $result '$result'
    return $result
}

# Apply the given env-var changes.
function applyChanges($envVarChanges) {
    foreach ($key in $envVarChanges.Keys) {
        Set-Item env:$key -Value $envVarChanges[$key]
    }
}

# .SYNOPSIS
# Run a .bat or .cmd script, and capture the changes it makes to environment variables, for later use with Invoke-CommandWithEnvDelta.
# 
# .RETURNS
# A hashtable with 'apply' and 'prev' keys, for use with Invoke-CommandWithEnvDelta. Each value is a hashtable of env-var name-value pairs.
# The 'prev' key is just for information.
function Export-EnvDeltaFromInvokedBatchScript([string] $script, [string] $parameters, [bool] $checkExitCode=$true) {
    $currentEnvironment = captureCurrentEnv
    # Write-Debug-SimpleHashtable $currentEnvironment "current environment"

    $newEnvironment = runCmdAndCaptureEnv $script $parameters $checkExitCode
    # Write-Debug-SimpleHashtable $newEnvironment "new environment"

    # We add -MissingInAfterMeansDeletion because: In this case, if the new environment is missing an item, we believe the script we just ran deleted it, on purpose.
    return calculateEnvDelta $currentEnvironment $newEnvironment -MissingInAfterMeansDeletion
}

# .SYNOPSIS
# Temporarily applies the given environment change - environment variables to add, change, or (empty string) remove,
# while running the given script.
# 
# We assume the $script doesn't itself modify environment vars. Any such changes would not be 
# reverted afterwards (unless they happen to be named in $EnvDelta).
#
# The intent is that the script will call out to some tool (whose changes to envvars will not affect the current script).
#
function Invoke-CommandWithEnvDelta([scriptblock] $script, $optionalEnvDelta) {
    if ($null -eq $optionalEnvDelta) {
        $EnvDelta = @{ apply = @{}; prev = @{}}
    } else {
        $EnvDelta = $optionalEnvDelta
    }
    $savedEnvironment = captureCurrentEnv
    $toRevert = (calculateEnvDelta $savedEnvironment $EnvDelta.apply).prev
    # Write-DebugValue $toRevert '$toRevert'

    applyChanges $EnvDelta.apply
    try {
        & $script
    } finally {
        applyChanges $toRevert
    }
}

