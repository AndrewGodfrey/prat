BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-ProjectTestOutputDir" {
    It "namespaces under the top-level repo root, using the project id's last segment" {
        $project = @{ root = "C:/does-not-exist"; id = "myrepo/myproject"; repo = @{ root = "C:/myrepo" } }

        Get-ProjectTestOutputDir $project | Should -Be "C:/myrepo/auto/testRuns/myproject"
    }

    It "uses the whole id as the leaf when there is no parent segment" {
        $project = @{ root = "C:/does-not-exist"; id = "myproject"; repo = @{ root = "C:/myrepo" } }

        Get-ProjectTestOutputDir $project | Should -Be "C:/myrepo/auto/testRuns/myproject"
    }

    It "falls back to the git toplevel (via Get-ProjectRepoRoot) when there is no parent repo" {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        New-Item -ItemType Directory "$root/gitRepo/standalone" -Force | Out-Null
        Push-Location "$root/gitRepo"
        try { git init --quiet } finally { Pop-Location }
        $project = @{ root = "$root/gitRepo/standalone"; id = "standalone" }

        Get-ProjectTestOutputDir $project | Should -Be "$root/gitRepo/auto/testRuns/standalone"
    }
}
