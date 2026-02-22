BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1"

    $coverageScript = "$PSScriptRoot/../Invoke-PesterWithCodeCoverage.ps1"
}

Describe "Invoke-PesterWithCodeCoverage" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        $script:outConf = $null
        $refOutConf = [ref] $script:outConf
        Mock Invoke-PesterAsJob { $refOutConf.Value = $Configuration }
    }

    It "calls Invoke-PesterAsJob" {
        & $coverageScript -Coverage:$false -PathToTest "somePath" -RepoRoot "somePath"

        Should -Invoke Invoke-PesterAsJob -Times 1
        $outConf.Run.Path.Value | Should -Be @("somePath")
        $outConf.CodeCoverage.Enabled.Value | Should -Be $false
        $outConf.Output.Verbosity.Value | Should -Not -Be "Detailed"
    }

    It "supports -Verbose" {
        & $coverageScript -Coverage:$false -PathToTest "somePath" -RepoRoot "somePath" -Verbose

        $outConf.Output.Verbosity.Value | Should -Be "Detailed"
    }

    It "supports code coverage" {
        & $coverageScript -Coverage:$true -PathToTest "somePath" -RepoRoot "someRepo"

        $outConf.Run.Path.Value | Should -Be @("somePath")
        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.OutputFormat.Value | Should -Be "CoverageGutters"  # For integration with vscode "Coverage Gutters" extension.
        $outConf.CodeCoverage.Path.Value | Should -Be @("someRepo")
    }

    It "supports coverage with a subset" {
        & $coverageScript -Coverage:$true -PathToTest "someRepo/subdir" -RepoRoot "someRepo"

        $outConf.Run.Path.Value | Should -Be @("someRepo/subdir")
        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value | Should -Be @("someRepo")
    }

    It "scopes coverage to inferred production file when PathToTest is a test file" {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../pathbin/tests/testCb").Path

        & $coverageScript -Coverage:$true -PathToTest "$repoRoot/testCb_fileWithTests.Tests.ps1" -RepoRoot $repoRoot

        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value[0] | Should -BeLike "*testCb_fileWithTests.ps1*"
        $outConf.Run.Path.Value[0] | Should -BeLike "*testCb_fileWithTests.Tests.ps1*"
    }

    It "defaults to Standard if inferred production file is not found" {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../pathbin/tests/testCb").Path

        & $coverageScript -Coverage:$true -PathToTest "$repoRoot/testCb_noMatchingProfFile.tests.ps1" -RepoRoot $repoRoot

        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value | Should -Be @($repoRoot)
    }
}
