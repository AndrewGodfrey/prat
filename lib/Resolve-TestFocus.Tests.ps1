BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Resolve-TestFocus" {
    It "returns '.' when Focus is empty" {
        &$scriptToTest | Should -Be "."
    }

    It "returns Focus as-is when it is an absolute path" {
        &$scriptToTest -Focus "/absolute/somePath" | Should -Be "/absolute/somePath"
    }

    It "joins Focus with RepoRoot when it is a relative path" {
        &$scriptToTest -Focus "lib/Foo.Tests.ps1" -RepoRoot "/my/repo" |
            Should -Be (Join-Path "/my/repo" "lib/Foo.Tests.ps1")
    }
}
