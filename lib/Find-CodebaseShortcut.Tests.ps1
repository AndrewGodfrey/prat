BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Find-CodebaseShortcut" {
    BeforeEach {
        function Get-GlobalCodebases {}
        function Get-CodebaseTables($loc) {}

        Mock Get-GlobalCodebases { return @('locA', 'locB') }
        Mock Get-CodebaseTables {
            switch ($loc) {
                'locA' {
                    return @{
                        repos     = @{ repoA = @{ id = 'repoA'; root = '/rootA' } }
                        shortcuts = @{ repoA = '/rootA'; shortA = '/rootA/foo' }
                    }
                }
                'locB' {
                    return @{
                        repos     = @{ repoB = @{ id = 'repoB'; root = '/rootB' } }
                        shortcuts = @{ repoB = '/rootB'; shortB = '/rootB/bar' }
                    }
                }
                default { return $null }
            }
        }
    }

    It "Returns the path for a known shortcut" {
        $result = &$scriptToTest "shortA"
        $result | Should -Be '/rootA/foo'
    }

    It "Returns null when shortcut is not found" {
        $result = &$scriptToTest "notexist"
        $result | Should -BeNull
    }

    It "Returns all shortcuts as a dict with -ListAll" {
        $result = &$scriptToTest -ListAll
        $result['shortA'] | Should -Be '/rootA/foo'
        $result['shortB'] | Should -Be '/rootB/bar'
    }

    It "First location wins when shortcut name appears in multiple locations" {
        Mock Get-GlobalCodebases { return @('loc1', 'loc2') }
        Mock Get-CodebaseTables {
            if ($loc -eq 'loc1') { return @{ repos = @{ a = @{ id = 'a'; root = '/a' } }; shortcuts = @{ shared = '/from-loc1' } } }
            if ($loc -eq 'loc2') { return @{ repos = @{ b = @{ id = 'b'; root = '/b' } }; shortcuts = @{ shared = '/from-loc2' } } }
            return $null
        }
        $result = &$scriptToTest "shared"
        $result | Should -Be '/from-loc1'
    }
}
