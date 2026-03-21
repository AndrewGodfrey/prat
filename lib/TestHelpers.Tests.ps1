BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "testText" {
    It "auto-detects columns from the first non-empty line" {
        testText "    hello`n    world" | Should -Be "hello`nworld"
    }
    It "preserves relative indentation" {
        testText "    a`n      b`n    c" | Should -Be "a`n  b`nc"
    }
}

Describe "testTextAt" {
    It "strips exactly the specified number of columns" {
        testTextAt 4 "    hello`n    world" | Should -Be "hello`nworld"
    }
    It "preserves relative indentation" {
        testTextAt 4 "    a`n      b`n    c" | Should -Be "a`n  b`nc"
    }
    It "trims trailing whitespace" {
        testTextAt 4 "    a`n    b`n    " | Should -Be "a`nb"
    }
}
