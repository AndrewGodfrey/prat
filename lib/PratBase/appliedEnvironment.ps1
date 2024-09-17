# .SYNOPSIS
# Functions for invoking a .bat script, and capturing the environment variables it changes.
# The purpose is for 'build enlistment' scripts. We periodically may need the other side-effects it has, but not every time.
# So we can periodically run it, capture the resulting environment changes, and then later just replay the environment changes when we
# want to build.
#
# Borrows from [Invoke-CmdScript.ps1](http://www.leeholmes.com/blog/2006/05/11/nothing-solves-everything-powershell-and-other-technologies/)


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

# Given an 'after' and 'before' capture, remove the variables in 'after' that were present and identical in 'before'.
# I.e. this is like a subtraction: ($after - $before)
# 
# Since emptying an env-var removes it, we can represent removed items as 'present but empty'.
function removeDuplicateVars($before, $after) {
    $result = @{}
    $seen = @{}
    foreach ($key in $after.Keys) {
        $seen[$key] = $true
        if ($before[$key] -ne $after[$key]) {
            $result[$key] = $after[$key]
        }
    }
    foreach ($key in $before.Keys) {
        if (!($seen[$key])) {
            $result[$key] = ""
        }
    }
    return $result
}

# Apply the given env-var changes. ($delta is expected to be the output of removeDuplicateVars).
function applyDelta($delta) {
    foreach ($key in $delta.Keys) {
        Set-Item env:$key -Value $delta[$key]
    }
}

# .SYNOPSIS
# Run a .bat or .cmd script, and capture the changes it makes to environment variables, for later use with Invoke-CommandWithAppliedEnvironment.
# 
# .RETURNS
# A hashtable with 'apply' and 'revert' keys, for use with Invoke-CommandWithAppliedEnvironment. Each value is a hashtable of env-var name-value pairs.
function Export-AppliedEnvironmentFromInvokedBatchScript([string] $script, [string] $parameters, [bool] $checkExitCode=$true) {
    $currentEnvironment = captureCurrentEnv
    # Write-Debug-SimpleHashtable $currentEnvironment "current environment"

    $newEnvironment = runCmdAndCaptureEnv $script $parameters $checkExitCode
    # Write-Debug-SimpleHashtable $newEnvironment "new environment"

    return @{
        apply = (removeDuplicateVars $currentEnvironment $newEnvironment)
        revert = (removeDuplicateVars $newEnvironment $currentEnvironment)
    }
}

# .SYNOPSIS
# Temporarily applies the given environment change - environment variables to add, change, or (empty string) remove,
# while running the given script.
# 
# We assume the $script doesn't itself modify environment vars. Any such changes would not be 
# reverted afterwards (unless they happen to be named in $appliedEnvironment).
#
# The intent is that the script will call out to some tool (whose changes to envvars will not affect the current script).
#
function Invoke-CommandWithAppliedEnvironment([scriptblock] $script, $appliedEnvironment) {
    applyDelta $appliedEnvironment.apply

    try {
        & $script
    } finally {
        applyDelta $appliedEnvironment.revert
    }
}


