BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Expand-TildePath" {
    It "Expands ~/<path> to absolute home path" {
        Expand-TildePath "~/prat" | Should -Be (Join-Path $home "prat")
    }

    It "Expands ~\<path> to absolute home path" {
        Expand-TildePath "~\prat" | Should -Be (Join-Path $home "prat")
    }

    It "Expands bare ~ to home directory" {
        Expand-TildePath "~" | Should -Be $home
    }

    It "Leaves absolute paths unchanged" {
        Expand-TildePath "C:\Users\foo" | Should -Be "C:\Users\foo"
    }

    It "Leaves relative paths unchanged" {
        Expand-TildePath "relative/path" | Should -Be "relative/path"
    }

    It "Returns empty string unchanged" {
        Expand-TildePath "" | Should -Be ""
    }

    It "Expands non-existent path without throwing" {
        Expand-TildePath "~/doesNotExist42" | Should -Be (Join-Path $home "doesNotExist42")
    }
}
