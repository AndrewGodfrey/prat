BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
    function makeTestProfile($testRepoDefinition) {
        "@{ '.' = @{ repos = @{ repo = $testRepoDefinition } } }" | Out-File $testProfilePath
    }
}

Describe "Find-JunctionIslandMismatch" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $testProfilePath = "$root\codebaseProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    It "Returns the project when the real path matches a junction-registered root only after resolving junctions" {
        New-Item -ItemType Directory "$root/realrepo" -Force | Out-Null
        New-Item -ItemType Junction  "$root/junction" -Target "$root/realrepo" | Out-Null
        makeTestProfile "@{ root = '$root/junction' }"

        $result = Find-JunctionIslandMismatch -Location "$root/realrepo"

        $result        | Should -Not -BeNullOrEmpty
        $result.id     | Should -Be "repo"
    }

    It "Returns null when the location is not a project even after resolving junctions" {
        New-Item -ItemType Directory "$root/realrepo" -Force | Out-Null
        New-Item -ItemType Directory "$root/unrelated" -Force | Out-Null
        New-Item -ItemType Junction  "$root/junction" -Target "$root/realrepo" | Out-Null
        makeTestProfile "@{ root = '$root/junction' }"

        (Find-JunctionIslandMismatch -Location "$root/unrelated") | Should -BeNull
    }
}
