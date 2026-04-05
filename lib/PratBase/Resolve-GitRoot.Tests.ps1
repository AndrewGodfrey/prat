BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}
BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Resolve-GitRoot" {
    BeforeAll {
        $realTestDrive = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
        $repoDir = "$realTestDrive/repo"
        New-Item -ItemType Directory $repoDir | Out-Null
        git -C $repoDir init -q
        New-Item "$repoDir/file.txt" | Out-Null
        git -C $repoDir add . 2>$null
        git -C $repoDir -c user.email="t@t" -c user.name="t" commit -q -m "init" 2>$null

        $startDir = "$realTestDrive/start"
        New-Item -ItemType Directory $startDir | Out-Null
        Push-Location $startDir
    }
    AfterAll {
        Pop-Location
    }

    It "Returns repo root for a file path inside a git repo" {
        $result = Resolve-GitRoot "$repoDir/file.txt"
        $result | Should -Be $repoDir
    }

    It "Returns repo root for a directory path inside a git repo" {
        $result = Resolve-GitRoot $repoDir
        $result | Should -Be $repoDir
    }

    It "Returns null/empty for a path not in any git repo" {
        $result = Resolve-GitRoot "$realTestDrive/notarepo"
        $result | Should -BeNullOrEmpty
    }

    It "Returns repo root when no path given and cwd is inside a git repo" {
        Push-Location $repoDir
        try {
            $result = Resolve-GitRoot
            $result | Should -Be $repoDir
        } finally {
            Pop-Location
        }
    }

    It "Returns null/empty when no path given and cwd is not in a git repo" {
        # cwd is $startDir (set in BeforeAll), which is not a git repo
        $result = Resolve-GitRoot
        $result | Should -BeNullOrEmpty
    }

    It "Restores cwd after call with no path (cwd is git repo)" {
        Push-Location $repoDir
        try {
            Resolve-GitRoot | Out-Null
            (Get-Location).Path | Should -Be ($repoDir -replace '/', '\')
        } finally {
            Pop-Location
        }
    }
}
