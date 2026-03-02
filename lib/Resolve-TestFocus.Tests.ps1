BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Resolve-TestFocus" {
    It "returns '.' when Focus is empty" {
        &$scriptToTest | Should -Be "."
    }

    It "returns absolute Focus as-is when it exists" {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\', '/')
        &$scriptToTest -Focus $dir | Should -Be $dir
    }

    It "joins relative Focus with RepoRoot when the file exists" {
        New-Item "TestDrive:\lib" -ItemType Directory -Force | Out-Null
        "# test" | Out-File "TestDrive:\lib\Foo.Tests.ps1"
        $repoRoot = (Get-Item "TestDrive:\").FullName.TrimEnd('\', '/')
        &$scriptToTest -Focus "lib/Foo.Tests.ps1" -RepoRoot $repoRoot |
            Should -Be (Join-Path $repoRoot "lib/Foo.Tests.ps1")
    }

    It "appends .Tests.ps1 when the base name doesn't exist but the test file does" {
        New-Item "TestDrive:\lib" -ItemType Directory -Force | Out-Null
        "# test" | Out-File "TestDrive:\lib\Foo.Tests.ps1"
        $repoRoot = (Get-Item "TestDrive:\").FullName.TrimEnd('\', '/')
        &$scriptToTest -Focus "lib/Foo" -RepoRoot $repoRoot |
            Should -Be (Join-Path $repoRoot "lib/Foo.Tests.ps1")
    }

    It "throws when neither path nor .Tests.ps1 exists" {
        { &$scriptToTest -Focus "TestDrive:/NoSuchDirXYZ/Foo" } | Should -Throw
    }
}
