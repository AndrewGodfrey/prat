BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    function makeTestProfile($testRepoDefinition) {
        "@{ '.' = @{ repos = @{ repo = $testRepoDefinition } } }" | Out-File $testProfilePath
    }
}

Describe "Get-PratProject" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $testProfilePath = "$root\repoProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    Context "simple cases" {
        It "Returns the repo object when location is inside a repo root" {
            New-Item -ItemType Directory "$root/myrepo" -Force | Out-Null
            makeTestProfile "@{ root = '$root/myrepo' }"

            $result = Get-PratProject -Location $root/myrepo

            $result.id     | Should -Be "repo"
            $result.root   | Should -Be "$root/myrepo"
            $result.subdir | Should -Be ''
            $result.ContainsKey('parentId') | Should -BeFalse
        }

        It "Returns null when location is not inside any repo root" {
            makeTestProfile "@{ root = '$root/myrepo' }"

            (Get-PratProject -Location $root) | Should -BeNull
        }

        It "Sets subdir relative to the project root" {
            New-Item -ItemType Directory "$root/a/b" -Force | Out-Null
            makeTestProfile "@{ root = '$root' }"

            (Get-PratProject -Location $root/a/b).subdir | Should -Be "a\b"
        }
    }

   Context "sub-projects" {
        It "Finds the subproject" {
            New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
            makeTestProfile "@{ root = '$root'; workspace = 'rootwsp'; subprojects = @{ sub = @{ path = 'lib/sub'; workspace = 'mywsp' } } }"

            $result = Get-PratProject -Location $root/lib/sub
            
            $result.id     | Should -Be "repo/sub"
            $result.root   | Should -Be "$root/lib/sub"
            $result.subdir | Should -Be ''
            $result.workspace | Should -Be "mywsp"
            $result.parentId  | Should -Be "repo"
        }

        It "Returns the repo directly when location doesn't match any subproject" {
            makeTestProfile "@{ root = '$root'; subprojects = @{ sub = @{ path = 'lib/sub' } } }"
            
            (Get-PratProject -Location $root).id | Should -Be "repo"
        }

        It "Sets subdir relative to the sub-project root, not the repo root" {
            New-Item -ItemType Directory "TestDrive:\lib\sub\src" -Force | Out-Null
            makeTestProfile "@{ root = '$root'; subprojects = @{ sub = @{ path = 'lib/sub' } } }"

            $result = Get-PratProject -Location $root/lib/sub/src

            $result.subdir | Should -Be "src"
            $result.root | Should -Be "$root/lib/sub"
        }

        It "Inherits parent properties" {
            New-Item -ItemType Directory "TestDrive:\lib\sub" -Force | Out-Null
            makeTestProfile "@{ root = '$root'; cachedEnvDelta = 'env.ps1'; subprojects = @{ sub = @{ path = 'lib/sub' } } }"
            
            (Get-PratProject -Location $root/lib/sub).cachedEnvDelta | Should -Be "env.ps1"
        }

        It "Resolves ties using path length" {
            # This doesn't seem like a good way to model a nested repo, but it might be desirable for some cases, to control property inheritance.

            New-Item -ItemType Directory "TestDrive:\lib\sub\nested" -Force | Out-Null
            makeTestProfile "@{ root = '$root'; subprojects = @{ sub = @{ path = 'lib/sub' }; nested = @{ path = 'lib/sub/nested' } } }"

            (Get-PratProject -Location $root/lib/sub/nested).id | Should -Be "repo/nested"
        }
    }
}
