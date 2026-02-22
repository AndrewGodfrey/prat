BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../pathbin/tests/testCb").Path
    $coverageScope = "$PSScriptRoot/Get-CoverageScope.ps1"
}

Describe "Get-CoverageScope" {
    It "just returns pathToTest, if it's a directory" {
        $result = & $coverageScope -PathToTest $repoRoot -RepoRoot "nonsense"
        $result | Should -Be $repoRoot
    }

    It "infers production file path from a test file" {
        $result = & $coverageScope -PathToTest "$repoRoot/testCb_fileWithTests.Tests.ps1" -RepoRoot $repoRoot
        $result | Should -Be "$repoRoot\testCb_fileWithTests.ps1"
    }

    It "falls back to RepoRoot when no production file is found" {
        $result = & $coverageScope -PathToTest "$repoRoot/testCb_noMatchingProfFile.tests.ps1" -RepoRoot $repoRoot
        $result | Should -Be $repoRoot
    }

    It "falls back to RepoRoot for a non-existent path" {
        $result = & $coverageScope -PathToTest "nonexistent/fake.tests.ps1" -RepoRoot $repoRoot
        $result | Should -Be $repoRoot
    }
}
