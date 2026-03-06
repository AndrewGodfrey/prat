BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Find-ProjectShortcut" {
    BeforeEach {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testProfilePath = "$dir/repoProfile_test.ps1"

        "@{ '.' = @{ repos = @{ repoA = @{ root = 'rootA'; subprojects = @{ subA = @{ path = 'subA' } } } }; shortcuts = @{ shortA = 'rootA/foo' } } }" | Out-File $testProfilePath
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    It "Returns the path for a known shortcut" {
        $result = Find-ProjectShortcut "shortA"
        $result | Should -Be "$dir/rootA/foo"
    }

    It "Returns null when shortcut is not found" {
        $result = Find-ProjectShortcut "notexist"
        $result | Should -BeNull
    }

    It "Returns all shortcuts as a dict with -ListAll" {
        $pathB = "$dir/repoProfile_b.ps1"
        "@{ '.' = @{ repos = @{ repoB = @{ root = 'rootB' } }; shortcuts = @{ shortB = 'rootB/bar' } } }" | Out-File $pathB
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath, $pathB) }

        $result = Find-ProjectShortcut -ListAll
        $result['shortA'] | Should -Be "$dir/rootA/foo"
        $result['shortB'] | Should -Be "$dir/rootB/bar"
    }

    It "First file wins when shortcut name appears in multiple files" {
        $pathB = "$dir/repoProfile_b.ps1"
        "@{ '.' = @{ repos = @{ repoB = @{ root = 'b' } }; shortcuts = @{ shared = 'b/from-file2' } } }" | Out-File $pathB

        $pathA = "$dir/repoProfile_a.ps1"
        "@{ '.' = @{ repos = @{ repoA = @{ root = 'a' } }; shortcuts = @{ shared = 'a/from-file1' } } }" | Out-File $pathA

        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($pathA, $pathB) }

        $result = Find-ProjectShortcut "shared"
        $result | Should -Be "$dir/a/from-file1"
    }

    It "Finds subprojects using the full id" {
        $result = Find-ProjectShortcut "repoA/subA"
        $result | Should -Be "$dir/rootA/subA"
    }

    It "Finds subprojects using the last segment of the id" {
        $result = Find-ProjectShortcut "subA"
        $result | Should -Be "$dir/rootA/subA"
    }
}
