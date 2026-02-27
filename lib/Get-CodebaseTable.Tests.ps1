BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Get-CodebaseTable" {
    It "Returns null when no cbTable.ps1 exists for the location" {
        New-Item -ItemType Directory "TestDrive:\loc_noTable" | Out-Null
        $result = &$scriptToTest -Location (Get-Item "TestDrive:\loc_noTable").FullName
        $result | Should -BeNull
    }

    It "Returns the matching codebase entry for a location inside its root" {
        $result = &$scriptToTest -Location $PSScriptRoot
        $result | Should -Not -BeNull
        $result.id | Should -Be "prat"
    }

    It "Sets subdir as the path relative to the codebase root" {
        $result = &$scriptToTest -Location "$PSScriptRoot\Installers"
        $result.subdir | Should -Be "lib\Installers"
    }

    It "Throws when multiple codebase entries match the location" {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        "@{ a = @{ root = '$root' }; b = @{ root = '$root' } }" | Out-File "TestDrive:\cbTable.test.ps1"
        New-Item -ItemType Directory "TestDrive:\loc2" | Out-Null
        { &$scriptToTest -Location (Get-Item "TestDrive:\loc2").FullName } | Should -Throw "Found too many matches*"
    }

    It "Returns null when location is not inside any codebase root" {
        "@{ mykey = @{ root = 'C:\Foo' } }" | Out-File "TestDrive:\cbTable.test.ps1"
        New-Item -ItemType Directory "TestDrive:\loc" | Out-Null
        $result = &$scriptToTest -Location (Get-Item "TestDrive:\loc").FullName
        $result | Should -BeNull
    }
}
