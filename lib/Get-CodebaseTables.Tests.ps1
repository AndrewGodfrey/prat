BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Get-CodebaseTables" {
    It "Returns null when no cbTable.ps1 exists in parent tree" {
        New-Item -ItemType Directory "TestDrive:\loc" | Out-Null
        $result = &$scriptToTest (Resolve-Path "TestDrive:\loc").Path
        $result | Should -BeNull
    }

    It "Sets id from the key name in the table" {
        "@{ mykey = @{} }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result["mykey"].id | Should -Be "mykey"
    }

    It "Sets root to the cbTable file directory when not specified in the entry" {
        "@{ mykey = @{} }" | Out-File "TestDrive:\cbTable.test.ps1"
        $expectedRoot = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        $result = &$scriptToTest "TestDrive:\"
        $result["mykey"].root | Should -Be $expectedRoot
    }

    It "Uses the explicit root from the entry when specified" {
        "@{ mykey = @{ root = 'C:\Foo' } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result["mykey"].root | Should -Be "C:\Foo"
    }

    It "Strips trailing backslash from root when root is not a drive root" {
        "@{ mykey = @{ root = 'C:\Foo\' } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result["mykey"].root | Should -Be "C:\Foo"
    }

    It "Preserves trailing backslash when root is a drive root" {
        "@{ mykey = @{ root = 'C:\' } }" | Out-File "TestDrive:\cbTable.test.ps1"
        $result = &$scriptToTest (Resolve-Path "TestDrive:\").Path
        $result["mykey"].root | Should -Be "C:\"
    }
}
