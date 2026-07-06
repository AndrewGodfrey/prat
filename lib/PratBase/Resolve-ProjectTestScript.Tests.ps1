BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Resolve-ProjectTestScript" {
    It "returns the project's own test script without consulting Get-DetectedTestFrameworks" {
        Mock Get-DetectedTestFrameworks -ModuleName PratBase { throw "should not be called — project has its own test" }
        $project = @{ root = "C:/does-not-exist"; test = "C:/explicit/test.ps1" }

        Resolve-ProjectTestScript $project | Should -Be "C:/explicit/test.ps1"
    }

    It "returns Invoke-DetectedProjectTest.ps1 when a framework is detected" {
        Mock Get-DetectedTestFrameworks -ModuleName PratBase { @('pytest') }
        $project = @{ root = "C:/does-not-exist" }

        Resolve-ProjectTestScript $project | Should -Match 'Invoke-DetectedProjectTest\.ps1$'
    }

    It "returns the same dispatcher regardless of which framework was detected" {
        Mock Get-DetectedTestFrameworks -ModuleName PratBase { @('dotnet') }
        $project = @{ root = "C:/does-not-exist" }

        Resolve-ProjectTestScript $project | Should -Match 'Invoke-DetectedProjectTest\.ps1$'
    }

    It "returns the same dispatcher when both frameworks are detected" {
        Mock Get-DetectedTestFrameworks -ModuleName PratBase { @('pytest', 'dotnet') }
        $project = @{ root = "C:/does-not-exist" }

        Resolve-ProjectTestScript $project | Should -Match 'Invoke-DetectedProjectTest\.ps1$'
    }

    It "returns null when the project has no test and no framework is detected" {
        Mock Get-DetectedTestFrameworks -ModuleName PratBase { @() }
        $project = @{ root = "C:/does-not-exist" }

        Resolve-ProjectTestScript $project | Should -BeNullOrEmpty
    }
}
