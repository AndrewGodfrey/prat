BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
}

Describe "Get-PratProject" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $testProfilePath = "$root\repoProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    It "Returns null when location is not inside any repo root" {
        "@{ '.' = @{ repos = @{ repo = @{ root = '$root/myrepo' } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location $root
        $result | Should -BeNull
    }

    It "Returns the repo directly when location doesn't match any subproject" {
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location $root
        $result.id | Should -Be "repo"
    }

    It "Returns a sub-project when inside a subproject directory" {
        New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location (Get-Item "TestDrive:\lib\sub").FullName
        $result.id   | Should -Be "repo/sub"
        $result.root | Should -Be "$root/lib/sub"
    }

    It "Sets subdir relative to the sub-project root, not the repo root" {
        New-Item -ItemType Directory "TestDrive:\lib\sub\src" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location (Get-Item "TestDrive:\lib\sub\src").FullName
        $result.subdir | Should -Be "src"
    }

    It "Picks the most-specific subproject when multiple match" {
        New-Item -ItemType Directory "TestDrive:\lib\sub\nested" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' }; nested = @{ path = 'lib/sub/nested' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location (Get-Item "TestDrive:\lib\sub\nested").FullName
        $result.id | Should -Be "repo/nested"
    }

    It "Inherits repo properties (e.g. cachedEnvDelta) into the sub-project" {
        New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; cachedEnvDelta = 'env.ps1'; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location (Get-Item "TestDrive:\lib\sub").FullName
        $result.cachedEnvDelta | Should -Be "env.ps1"
    }

    It "Sets workspace from subproject definition" {
        New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub'; workspace = 'mywsp' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location (Get-Item "TestDrive:\lib\sub").FullName
        $result.workspace | Should -Be "mywsp"
    }

    It "Sets parentId on subproject result" {
        New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location (Get-Item "TestDrive:\lib\sub").FullName
        $result.parentId | Should -Be "repo"
    }

    It "Does not set parentId on top-level repo result" {
        "@{ '.' = @{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath
        $result = Get-PratProject -Location $root
        $result.ContainsKey('parentId') | Should -BeFalse
    }
}
