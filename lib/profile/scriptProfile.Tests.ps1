BeforeAll {
    $script:profileScript = Join-Path $PSScriptRoot 'scriptProfile.ps1'
    $script:drive         = (Get-Item "TestDrive:\").FullName
}

Describe "scriptProfile generated-output redirection" {
    It "leaves no .pytest_cache behind when pytest is run by hand" {
        # pytest writes .pytest_cache into its rootdir, which for an ad-hoc run is the directory the
        # caller happened to be in - i.e. inside a source tree, holding a .gitignore that ignores
        # itself, so no git status ever reports it. Invoke-PytestWithSummary passes
        # -p no:cacheprovider for the runs it makes; this covers every other way pytest gets run.
        $project = Join-Path $drive 'adhocPytest'
        New-Item $project -ItemType Directory | Out-Null
        Set-Content "$project/test_probe.py" "def test_ok():`n    assert True`n"
        $probe = Join-Path $drive 'pytestCacheProbe.ps1'
        Set-Content $probe @"
. '$profileScript'
Set-Location '$project'
python -m pytest -q
"@

        $out = pwsh -NoProfile -File $probe 2>&1

        # The absence below means nothing unless pytest actually ran.
        ($out -join "`n") | Should -Match '1 passed'
        Test-Path "$project/.pytest_cache" | Should -BeFalse
    }
}
