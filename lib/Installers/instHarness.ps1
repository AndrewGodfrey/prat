function Install-HarnessIntegration {
    param($stage, [string] $harness, [string[]] $Suppress = @(), [string[]] $Enable = @(), [hashtable] $Config = @{})
    switch ($harness) {
        'claude'  { Install-ClaudeHarness  $stage -Suppress $Suppress -Enable $Enable -Config $Config }
        'copilot' { Install-CopilotHarness $stage }
        default   { throw "Unknown harness: '$harness'" }
    }
}
