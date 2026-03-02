BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Get-PratProject" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        function Get-GlobalCodebases {}
        Mock Get-GlobalCodebases { return @($root) }
    }

    It "Returns null when location is not inside any codebase root" {
        "@{ repos = @{ repo = @{ root = '$root/myrepo' } } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest -Location $root
        $result | Should -BeNull
    }

    It "Returns the repo directly when location doesn't match any subproject" {
        "@{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest -Location $root
        $result.id | Should -Be "repo"
    }

    It "Returns a sub-project when inside a subproject directory" {
        New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
        "@{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest -Location (Get-Item "TestDrive:\lib\sub").FullName
        $result.id   | Should -Be "repo/sub"
        $result.root | Should -Be "$root/lib/sub"
    }

    It "Sets subdir relative to the sub-project root, not the codebase root" {
        New-Item -ItemType Directory "TestDrive:\lib\sub\src" -Force | Out-Null
        "@{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' } } } } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest -Location (Get-Item "TestDrive:\lib\sub\src").FullName
        $result.subdir | Should -Be "src"
    }

    It "Picks the most-specific subproject when multiple match" {
        New-Item -ItemType Directory "TestDrive:\lib\sub\nested" -Force | Out-Null
        "@{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub' }; nested = @{ path = 'lib/sub/nested' } } } } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest -Location (Get-Item "TestDrive:\lib\sub\nested").FullName
        $result.id | Should -Be "repo/nested"
    }

    It "Inherits codebase properties (e.g. cachedEnvDelta) into the sub-project" {
        New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
        "@{ repos = @{ repo = @{ root = `$PSScriptRoot; cachedEnvDelta = 'env.ps1'; subprojects = @{ sub = @{ path = 'lib/sub' } } } } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest -Location (Get-Item "TestDrive:\lib\sub").FullName
        $result.cachedEnvDelta | Should -Be "env.ps1"
    }

    It "Sets workspace from subproject definition" {
        New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
        "@{ repos = @{ repo = @{ root = `$PSScriptRoot; subprojects = @{ sub = @{ path = 'lib/sub'; workspace = 'mywsp' } } } } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest -Location (Get-Item "TestDrive:\lib\sub").FullName
        $result.workspace | Should -Be "mywsp"
    }
}
