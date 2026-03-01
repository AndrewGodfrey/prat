
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
