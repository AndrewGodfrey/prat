BeforeAll {
    $gate     = Join-Path $PSScriptRoot 'Initialize-PratScriptEnvironment.ps1'
    $realDrive = (Get-Item "TestDrive:\").FullName

    # Runs a probe script in a fresh `pwsh -NoProfile` child (the harness condition we bootstrap for)
    # and returns its stdout lines.
    function Invoke-InNoProfilePwsh([string] $Body, [string] $Name) {
        $probe = Join-Path $realDrive $Name
        Set-Content -Path $probe -Value $Body -Encoding utf8
        return pwsh -NoProfile -File $probe 2>&1
    }
}

Describe "Initialize-PratScriptEnvironment" {
    It "bootstraps the prat environment when it is not already loaded" {
        $body = @"
if (Test-Path Function:\Get-PratProject) { 'PRESENT-BEFORE'; exit 3 }
. '$gate'
if (Test-Path Function:\Get-PratProject) { 'LOADED' } else { 'MISSING' }
"@
        $out = Invoke-InNoProfilePwsh $body 'probe-absent.ps1'
        $out | Should -Contain 'LOADED'
        $out | Should -Not -Contain 'PRESENT-BEFORE'
    }

    It "is a no-op when the environment is already loaded" {
        # A sentinel Get-PratProject stands in for an already-loaded environment. If the gate wrongly
        # re-ran scriptProfile, it would replace this with the real function, changing the output.
        $body = @"
function Get-PratProject { 'FAKE-SENTINEL' }
. '$gate'
Get-PratProject
"@
        $out = Invoke-InNoProfilePwsh $body 'probe-present.ps1'
        $out | Should -Be 'FAKE-SENTINEL'
    }
}
