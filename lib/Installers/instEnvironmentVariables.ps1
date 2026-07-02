
# Thin wrappers around the persistent (registry-backed) User environment scope, so tests can mock
# persistence without touching the real registry.
function getUserEnvironmentVariable([string] $Name) {
    [System.Environment]::GetEnvironmentVariable($Name, 'User')
}
function setUserEnvironmentVariable([string] $Name, [string] $Value) {
    [System.Environment]::SetEnvironmentVariable($Name, $Value, 'User')
}

# Sets a persistent user-level environment variable (written to HKCU\Environment). Reports its
# actions & inactions to $stage. Also sets the variable in the current process environment,
# so callers don't need a separate $env: assignment.
function Install-UserEnvironmentVariable($stage, [string] $Name, [string] $Value) {
    $current = getUserEnvironmentVariable $Name
    if ($current -ne $Value) {
        $stage.OnChange()
        setUserEnvironmentVariable $Name $Value

        # Update the current process too. But this doesn't help with other already-running instances.
        [System.Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    }
}

# Adds $Path to the user's persistent PATH (registry) if not already present, and ensures it is
# also in the current process PATH.
#
# -Prepend puts $Path at the very front instead of the end — ahead of the inherited system PATH
# too (e.g. a Windows "App execution alias" stub in %LOCALAPPDATA%\Microsoft\WindowsApps, which
# Windows places in the User PATH ahead of anything merely appended here). If $Path already
# exists elsewhere in PATH, it's moved to the front rather than duplicated.
#
# Note: That still leaves a gap, in other already-open processes.
function Install-UserPathEntry($stage, [string] $Path, [switch] $CurrentProcessOnly=$false, [switch] $Prepend=$false) {
    $Path = ($Path -replace '/', '\')
    if (!$CurrentProcessOnly) {
        $userPath = getUserEnvironmentVariable "PATH"
        $entries = @(($userPath -split ';') | Where-Object { $_ -ne '' })
        if ($Prepend) {
            if ($entries.Count -eq 0 -or $entries[0] -ine $Path) {
                $stage.OnChange()
                $newEntries = @($Path) + @($entries | Where-Object { $_ -ine $Path })
                setUserEnvironmentVariable "PATH" ($newEntries -join ';')
            }
        } elseif ($entries -notcontains $Path) {
            $stage.OnChange()
            setUserEnvironmentVariable "PATH" ($userPath.TrimEnd(';') + ";$Path")
        }
    }

    $procEntries = @(($env:PATH -split ';') | Where-Object { $_ -ne '' })
    if ($Prepend) {
        if ($procEntries.Count -eq 0 -or $procEntries[0] -ine $Path) {
            $stage.OnChange()
            $env:PATH = (@($Path) + @($procEntries | Where-Object { $_ -ine $Path })) -join ';'
        }
    } elseif ($procEntries -notcontains $Path) {
        $stage.OnChange()
        if (!$env:PATH.EndsWith(";")) { $env:PATH += ";" }
        $env:PATH += $Path
    }
}
