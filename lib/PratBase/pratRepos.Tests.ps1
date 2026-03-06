BeforeAll {
    Import-Module "$PSScriptRoot\PratBase.psd1" -Force
}

Describe "Get-PratRepo" {
    BeforeAll {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        New-Item -ItemType Directory -Path "TestDrive:\myrepo" | Out-Null
        New-Item -ItemType Directory -Path "TestDrive:\myrepo\sub" | Out-Null
        New-Item -ItemType Directory -Path "TestDrive:\myrepo-other" | Out-Null
        "@{ '.' = @{ repos = @{ myrepo = @{} } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$dir/repoProfile_test.ps1") }
    }

    It "Matches a location inside the repo" {
        (Get-PratRepo "$dir/myrepo/sub").id | Should -Be "myrepo"
    }

    It "Does not match a sibling directory that shares a name prefix" {
        Get-PratRepo "$dir/myrepo-other" | Should -BeNull
    }

    It "Matches when exactly at the repo root" {
        (Get-PratRepo "$dir/myrepo").id | Should -Be "myrepo"
    }
}

Describe "Find-ProjectShortcut" {
    BeforeEach {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
    }

    It "-ListAll returns shortcuts sorted alphabetically" {
        "@{ '.' = @{ repos = @{ z = @{} }; shortcuts = @{ b = 'b'; a = 'a' } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$dir/repoProfile_test.ps1") }

        $keys = @((Find-ProjectShortcut -ListAll).Keys)

        $keys | Should -Be ($keys | Sort-Object)
    }
}

Describe "Import-Scriptblock" {
    InModuleScope PratBase {
        BeforeEach {
            $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        }

        It "Strips module association from top-level scriptblocks" {
            "@{ sb = { 'hello' } }" | Out-File "TestDrive:\t.ps1"
            (Import-Scriptblock "$dir/t.ps1").sb.Module | Should -BeNull
        }

        It "Strips module association from scriptblocks nested in hashtables" {
            "@{ outer = @{ sb = { 'hello' } } }" | Out-File "TestDrive:\t.ps1"
            (Import-Scriptblock "$dir/t.ps1").outer.sb.Module | Should -BeNull
        }

        It "Non-scriptblock values pass through unchanged" {
            "@{ x = 42; s = 'hello' }" | Out-File "TestDrive:\t.ps1"
            $result = Import-Scriptblock "$dir/t.ps1"
            $result.x | Should -Be 42
            $result.s | Should -Be 'hello'
        }

        It "LIMITATION: Closures are not preserved - variable resolves at invocation time, not capture time" {
            # After stripping, the scriptblock source text is recompiled with no captured environment.
            # $x is looked up in the caller's scope at invocation time, not the original closure scope.
            # Workaround: use [scriptblock]::Create() in the data file to bake values into source text.
            $x = "at-definition"
            $sb = { $x }.GetNewClosure()
            $stripped = Strip-Scriptblocks $sb
            $x = "at-invocation"
            & $stripped | Should -Be "at-invocation"  # NOT "at-definition"
        }
    }
}

Describe "Get-PratRepoIndex" {
    InModuleScope PratBase {
        BeforeAll {
            function makeIndex($content) {
                $content | Out-File "TestDrive:\repoProfile_test.ps1"
                Get-PratRepoIndex @("$dir/repoProfile_test.ps1")
            }
        }

        BeforeEach {
            $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        }

        It "Returns null when given an empty list" {
            Get-PratRepoIndex @() | Should -BeNull
        }

        It "Returns null when given null" {
            Get-PratRepoIndex $null | Should -BeNull
        }

        Context "root resolution" {
            It "Sets repo id from its key name" {
                (makeIndex "@{ '.' = @{ repos = @{ myrepo = @{} } } }").repos["myrepo"].id | Should -Be "myrepo"
            }

            It "Repo root defaults to sectionRoot/id; '.' resolves to file directory" {
                (makeIndex "@{ '.' = @{ repos = @{ myrepo = @{} } } }").repos["myrepo"].root | Should -Be "$dir/myrepo"
            }

            It "Repo root defaults to sectionRoot/id when section key is an absolute path" {
                (makeIndex "@{ 'C:/base' = @{ repos = @{ myrepo = @{} } } }").repos["myrepo"].root | Should -Be "C:/base/myrepo"
            }

            It "Relative section key is resolved against the file's directory" {
                New-Item -ItemType Directory "TestDrive:\subdir" | Out-Null
                (makeIndex "@{ 'subdir' = @{ repos = @{ r = @{} } } }").repos["r"].root | Should -Be "$dir/subdir/r"
            }

            It "Uses explicit absolute per-repo root when specified" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{ root = 'C:/explicit' } } } }").repos["r"].root | Should -Be "C:/explicit"
            }

            It "Resolves explicit relative per-repo root against section root" {
                (makeIndex "@{ 'C:/base' = @{ repos = @{ r = @{ root = 'nested/sub' } } } }").repos["r"].root | Should -Be "C:/base/nested/sub"
            }

            It "Resolves explicit relative per-repo root against '.' section root" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{ root = 'nested/sub' } } } }").repos["r"].root | Should -Be "$dir/nested/sub"
            }

            It "Strips trailing path separator from root" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{ root = 'C:/myroot/' } } } }").repos["r"].root | Should -Be "C:/myroot"
            }
        }

        Context "shortcuts" {
            It "Relative shortcut paths are resolved against the '.' section root (file dir)" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{} }; shortcuts = @{ sub = 'subdir' } } }").shortcuts["sub"] | Should -Be "$dir/subdir"
            }

            It "Relative shortcut paths are resolved against an explicit section root" {
                (makeIndex "@{ 'C:/git' = @{ repos = @{ r = @{} }; shortcuts = @{ sub = 'subdir' } } }").shortcuts["sub"] | Should -Be "C:/git/subdir"
            }

            It "Leaves already-absolute shortcut paths unchanged" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{} }; shortcuts = @{ s = 'C:/abs' } } }").shortcuts["s"] | Should -Be "C:/abs"
            }

            It "Adds implicit shortcut id->root for each repo" {
                (makeIndex "@{ '.' = @{ repos = @{ myrepo = @{} } } }").shortcuts["myrepo"] | Should -Be "$dir/myrepo"
            }

            It "Explicit shortcut overrides implicit id->root shortcut" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{} }; shortcuts = @{ r = 'override' } } }").shortcuts["r"] | Should -Be "$dir/override"
            }

            It "Repo-level shortcuts are resolved relative to the repo root" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{ root = 'C:/myrepo'; shortcuts = @{ sub = 'lib' } } } } }").shortcuts["sub"] | Should -Be "C:/myrepo/lib"
            }
        }

        Context "multi-file merging" {
            It "Merges repos and shortcuts from multiple files, first-file-wins for shortcuts" {
                "@{ '.' = @{ repos = @{ repoA = @{} }; shortcuts = @{ shared = '/from-file1' } } }" | Out-File "TestDrive:\repoProfile_a.ps1"
                "@{ '.' = @{ repos = @{ repoB = @{} }; shortcuts = @{ shared = '/from-file2' } } }" | Out-File "TestDrive:\repoProfile_b.ps1"

                $index = Get-PratRepoIndex @("$dir/repoProfile_a.ps1", "$dir/repoProfile_b.ps1")

                $index.repos.Keys | Should -Contain "repoA"
                $index.repos.Keys | Should -Contain "repoB"
                $index.shortcuts["shared"] | Should -Be "/from-file1"
            }
        }

        Context "command properties" {
            It "Resolves a relative string command property to absolute path (relative to repoProfile dir)" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{ test = 'commands/test.ps1' } } } }").repos["r"].test | Should -Be "$dir/commands/test.ps1"
            }

            It "Leaves an already-absolute string command property unchanged" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{ test = 'C:/absolute/test.ps1' } } } }").repos["r"].test | Should -Be "C:/absolute/test.ps1"
            }

            It "Leaves a scriptblock command property as a scriptblock" {
                (makeIndex "@{ '.' = @{ repos = @{ r = @{ test = { 'hello' } } } } }").repos["r"].test | Should -BeOfType [scriptblock]
            }

            It "Scriptblock command properties are not bound to PratBase module" {
                $sb = (makeIndex "@{ '.' = @{ repos = @{ r = @{ test = { 'hello' } } } } }").repos["r"].test

                $sb.Module | Should -BeNull
            }

            It "Auto-discovers a command script from lib/projects/<id>/<cmd>.ps1" {
                New-Item -ItemType Directory -Path "TestDrive:\lib\projects\r" -Force | Out-Null
                "# auto" | Out-File "TestDrive:\lib\projects\r\test.ps1"

                (makeIndex "@{ '.' = @{ repos = @{ r = @{} } } }").repos["r"].test | Should -Be "$dir/lib/projects/r/test.ps1"
            }

            It "Explicit command entry takes precedence over auto-discovered file" {
                New-Item -ItemType Directory -Path "TestDrive:\lib\projects\r" -Force | Out-Null
                "# auto" | Out-File "TestDrive:\lib\projects\r\test.ps1"

                (makeIndex "@{ '.' = @{ repos = @{ r = @{ test = 'explicit/test.ps1' } } } }").repos["r"].test | Should -Be "$dir/explicit/test.ps1"
            }

            It "No command set and no auto-discover file means command is absent" {
                (makeIndex "@{ '.' = @{ repos = @{ noauto = @{} } } }").repos["noauto"].ContainsKey("test") | Should -BeFalse
            }
        }
    }
}
