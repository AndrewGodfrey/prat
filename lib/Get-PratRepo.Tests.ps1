BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Get-PratRepo" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        function Get-GlobalCodebases {}
        function Get-CodebaseTables {}
        Mock Get-GlobalCodebases { return @('loc') }
    }

    It "Returns null when location is not inside any repo root" {
        Mock Get-CodebaseTables { return @{ repos = @{ r = @{ id = 'r'; root = "$root\sub" } }; shortcuts = @{} } }
        
        &$scriptToTest -Location $root | Should -BeNull
    }

    It "Returns null when no repoProfile files are found" {
        Mock Get-CodebaseTables { return $null }

        &$scriptToTest -Location $root| Should -BeNull
    }

    It "Returns the matching repo for the given location" {
        Mock Get-CodebaseTables { return @{ repos = @{ myrepo = @{ id = 'myrepo'; root = $root } }; shortcuts = @{} } }

        (&$scriptToTest -Location $root).id | Should -Be 'myrepo'
    }

    It "Sets subdir as path relative to repo root" {
        New-Item -ItemType Directory "TestDrive:\sub" -Force | Out-Null
        Mock Get-CodebaseTables { return @{ repos = @{ r = @{ id = 'r'; root = $root } }; shortcuts = @{} } }

        (&$scriptToTest -Location (Get-Item "TestDrive:\sub").FullName).subdir | Should -Be "sub"
    }

    It "Throws when multiple repos match the location" {
        Mock Get-CodebaseTables { return @{ repos = @{ a = @{ id = 'a'; root = $root }; b = @{ id = 'b'; root = $root } }; shortcuts = @{} } }

        { &$scriptToTest -Location $root } | Should -Throw "Found too many matches"
    }

    It "Returns the most-specific (deepest) repo when nested repos both match" {
        New-Item -ItemType Directory "TestDrive:\sub" -Force | Out-Null
        Mock Get-CodebaseTables { return @{ repos = @{ parent = @{ id = 'parent'; root = $root }; child = @{ id = 'child'; root = "$root\sub" } }; shortcuts = @{} } }

        (&$scriptToTest -Location (Get-Item "TestDrive:\sub").FullName).id | Should -Be 'child'
    }

    It "Deduplicates repos with the same root across multiple locations" {
        Mock Get-GlobalCodebases { return @('loc1', 'loc2') }
        Mock Get-CodebaseTables { return @{ repos = @{ r = @{ id = 'r'; root = $root } }; shortcuts = @{} } }

        (&$scriptToTest -Location $root).id | Should -Be 'r'
    }
}
