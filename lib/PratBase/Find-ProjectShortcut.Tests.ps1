BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Find-ProjectShortcut" {
    BeforeAll {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testProfilePath = "$dir/repoProfile_test.ps1"
        $simpleRepo = "repoA = @{ root = 'rootA'; subprojects = @{ subA = @{ path = 'subA' } } }"

        function makeProfile($repoContent, $shortcutContent="", $filename = $testProfilePath) {
            "@{ '.' = @{ repos = @{ $repoContent }; shortcuts = @{ $shortcutContent } } }" | Out-File $filename
        }
    }
    Context "simple cases" {
        BeforeAll {
            makeProfile $simpleRepo "shortA = 'rootA/foo'"
            Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
        }

        It "Returns the path for a known shortcut" {
            Find-ProjectShortcut "shortA" | Should -Be "$dir/rootA/foo"
        }

        It "Returns null when shortcut is not found" {
            Find-ProjectShortcut "notexist" | Should -BeNull
        }

        It "Finds subprojects using the full id" {
            Find-ProjectShortcut "repoA/subA" | Should -Be "$dir/rootA/subA"
        }

        It "Finds subprojects using the last segment of the id" {
            Find-ProjectShortcut "subA" | Should -Be "$dir/rootA/subA"
        }
    }

    Context "multiple repo files" {
        It "Returns all shortcuts as a dict with -ListAll" {
            $pathB = "$dir/repoProfile_b.ps1"
            makeProfile $simpleRepo "shortA = 'rootA/foo'"
            makeProfile "repoB = @{ root = 'rootB' }" "shortB = 'rootB/bar'" $pathB
            Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath, $pathB) }

            $result = Find-ProjectShortcut -ListAll

            $result['shortA'] | Should -Be "$dir/rootA/foo"
            $result['shortB'] | Should -Be "$dir/rootB/bar"
        }

        It "picks the first file, when the same shortcut name appears in multiple files" {
            $pathB = "$dir/repoProfile_b.ps1"
            makeProfile "repoA = @{ root = 'a' }" "shared = 'a/from-file1'"
            makeProfile "repoB = @{ root = 'b' }" "shared = 'b/from-file2'" $pathB
            Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath, $pathB) }

            Find-ProjectShortcut "shared" | Should -Be "$dir/a/from-file1"
        }
    }

    Context "multiple matches" {
        It "throws, for identical shortcuts within the same profile file" {
            Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }

            $subA = "subA = @{ path = 'subA'; shortcuts = @{ foo = 'fooA' } }"
            $subB = "subB = @{ path = 'subB'; shortcuts = @{ foo = 'fooB' } }"
            $repo =  "repoA = @{ root = 'rootA'; subprojects = @{ $subA; $subB } }"
            makeProfile $repo

            { Find-ProjectShortcut "foo" } | Should -Throw "*Duplicate shortcut 'foo'*"
        }

        It "throws, for multiple partial matches of subprojects" {
            Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }

            $subA = "subA = @{ path = 'subA'; subprojects = @{ foo = @{ path = 'fooA' } } }"
            $subB = "subB = @{ path = 'subB'; subprojects = @{ foo = @{ path = 'fooB' } } }"
            $repo =  "repoA = @{ root = 'rootA'; subprojects = @{ $subA; $subB } }"
            makeProfile $repo

            {Find-ProjectShortcut "foo"} | Should -Throw "Found multiple partial matches for 'foo':*"
        }
    }
}
