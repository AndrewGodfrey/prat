BeforeAll {
    . "$PSScriptRoot/Invoke-PytestWithSummary.ps1"
}

Describe "Invoke-PytestWithSummary coverage generation" {
    BeforeAll {
        Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
        $script:pytestScript = "$PSScriptRoot/Invoke-PytestWithSummary.ps1"
    }

    It "omits test/conftest files and reports a single source root, with unrun modules force-reported" {
        $repoRoot = Join-Path $TestDrive "coverageRepo"
        New-Item $repoRoot -ItemType Directory | Out-Null
        New-Item "$repoRoot/providers" -ItemType Directory | Out-Null

        Set-Content "$repoRoot/main.py" @'
def add(a, b):
    return a + b
'@
        Set-Content "$repoRoot/unused.py" @'
def never_called():
    return 42
'@
        Set-Content "$repoRoot/providers/__init__.py" ''
        Set-Content "$repoRoot/providers/impl.py" @'
def unused_provider():
    return "x"
'@
        Set-Content "$repoRoot/conftest.py" ''
        Set-Content "$repoRoot/test_main.py" @'
from main import add

def test_add():
    assert add(1, 2) == 3
'@

        $result = & $script:pytestScript -RepoRoot $repoRoot -WorkingDir $repoRoot `
            -OutputDir "$repoRoot/auto/testRuns" -PassThru

        $result.FatalError | Should -BeNullOrEmpty
        $result.Passed | Should -Be 1

        $coverageXml = [xml](Get-Content "$($result.RunDir)/coverage.xml" -Raw)
        $sources = @($coverageXml.coverage.sources.source)
        $classes = @($coverageXml.SelectNodes("//class"))

        $sources.Count | Should -Be 1
        ($classes.filename | Where-Object { $_ -match 'test_main\.py$|conftest\.py$' }) | Should -BeNullOrEmpty

        $unusedClass = $classes | Where-Object { $_.filename -match 'unused\.py$' }
        $unusedClass | Should -Not -BeNullOrEmpty
        $unusedClass.'line-rate' | Should -Be '0'

        ($classes.filename | Where-Object { $_ -match 'impl\.py$' }) | Should -Not -BeNullOrEmpty
    }
}

Describe "parsePytestSummary" {
    It "returns null for a line not starting with '='" {
        parsePytestSummary "3 passed in 1.2s" | Should -BeNullOrEmpty
    }

    It "returns null for the session-start banner" {
        parsePytestSummary "===== test session starts =====" | Should -BeNullOrEmpty
    }

    It "returns null for the short-test-summary banner" {
        parsePytestSummary "===== short test summary info =====" | Should -BeNullOrEmpty
    }

    It "returns null for an '=' line with no recognized counts" {
        parsePytestSummary "===== 1.23s ====="  | Should -BeNullOrEmpty
    }

    It "parses a passed-only summary" {
        $result = parsePytestSummary "===== 3 passed in 1.2s ====="
        $result.Passed | Should -Be 3
        $result.Failed | Should -Be 0
    }

    It "parses a failed-only summary" {
        $result = parsePytestSummary "===== 2 failed in 1.2s ====="
        $result.Passed | Should -Be 0
        $result.Failed | Should -Be 2
    }

    It "parses a singular-error summary" {
        $result = parsePytestSummary "===== 1 error in 1.2s ====="
        $result.Passed | Should -Be 0
        $result.Failed | Should -Be 1
    }

    It "parses a plural-errors summary" {
        $result = parsePytestSummary "===== 3 errors in 1.2s ====="
        $result.Passed | Should -Be 0
        $result.Failed | Should -Be 3
    }

    It "folds errors into Failed alongside a separate failed count" {
        $result = parsePytestSummary "===== 4 passed, 2 failed, 1 error in 1.2s ====="
        $result.Passed | Should -Be 4
        $result.Failed | Should -Be 3
    }

    It "parses the no-tests-ran summary as zero passed and zero failed" {
        $result = parsePytestSummary "===== no tests ran in 0.01s ====="
        $result.Passed | Should -Be 0
        $result.Failed | Should -Be 0
    }
}
