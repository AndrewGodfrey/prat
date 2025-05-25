BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    $testRoots = @(
        "TestDrive:\foo_0",
        "TestDrive:\foo_1"
    )
    $codebaseTables = 0..1 | ForEach-Object {
        @{
            'shortcuts' = @{
                "abc$_"  = 'foo'
                "abcd$_" = 'foo2'
            }
            'root'      = $testRoots[$_]
            'id'        = "test$_"
        }
    }
    $index = @{}
    0..1 | ForEach-Object { $index[$testRoots[$_]] = $codebaseTables[$_] }
}

Describe "Main" {
    BeforeEach {
        function Get-globalCodebases {}
        Mock Get-GlobalCodebases { 
            $testRoots
        }

        function Get-CodebaseTable($Location) {} 
        Mock Get-CodebaseTable { $index[$Location] }
    }

    It "Finds a shortcut" {
        $result = &$scriptToTest "abc0"

        $result.id | Should -Be "test0"
    }

    It "Returns null if no match found" {
        &$scriptToTest "xyz" | Should -BeNull
    }

    It "Can list all codebases having shortcuts" {
        $result = &$scriptToTest "abc" -ListAll

        $result.Count | Should -Be 2
        $result[0].id | Should -Be "test0"
        $result[1].id | Should -Be "test1"
    }
}