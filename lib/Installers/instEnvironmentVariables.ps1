
# Sets a persistent user-level environment variable (written to HKCU\Environment). Reports its
# actions & inactions to $stage. Also sets the variable in the current process environment,
# so callers don't need a separate $env: assignment.
function Install-UserEnvironmentVariable($stage, [string] $Name, [string] $Value) {
    $current = [System.Environment]::GetEnvironmentVariable($Name, 'User')
    if ($current -ne $Value) {
        $stage.OnChange()
        [System.Environment]::SetEnvironmentVariable($Name, $Value, 'User')

        # Update the current process too. But this doesn't help with other already-running instances.
        [System.Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    }
}

# Adds $Path to the user's persistent PATH (registry) if not already present, and ensures it is
# also in the current process PATH.
#
# Note: That still leaves a gap, in other already-open processes.
function Install-UserPathEntry($stage, [string] $Path, [switch] $CurrentProcessOnly=$false) {
    $Path = ($Path -replace '/', '\')
    if (!$CurrentProcessOnly) {
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if (($userPath -split ';') -notcontains $Path) {
            $stage.OnChange()
            [Environment]::SetEnvironmentVariable("PATH", ($userPath.TrimEnd(';') + ";$Path"), "User")
        }
    }

    if (($env:PATH -split ';') -notcontains $Path) {
        $stage.OnChange()
        if (!$env:PATH.EndsWith(";")) { $env:PATH += ";" }
        $env:PATH += $Path
    }
}
