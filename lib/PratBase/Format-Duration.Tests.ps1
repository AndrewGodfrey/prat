BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Format-Duration" {
    Context "seconds" {
        It "1dp below 12s" {
            Format-Duration 1.53 | Should -Be '1.5s'
            Format-Duration 10.3 | Should -Be '10.3s'
        }

        It "0dp from 12s to 60s" {
            Format-Duration 12.3 | Should -Be '12s'
            Format-Duration 59.3 | Should -Be '59s'
        }
    }

    Context "compound" {
        It "m+s from 60s to 100s" {
            Format-Duration 65 | Should -Be '1m 5s'
            Format-Duration 99 | Should -Be '1m 39s'
        }
    }

    Context "minutes" {
        It "1dp from 100s to 720s" {
            Format-Duration 100 | Should -Be '1.7m'
            Format-Duration 719 | Should -Be '12.0m'
        }

        It "0dp from 720s to 3600s" {
            Format-Duration 720  | Should -Be '12m'
            Format-Duration 3500 | Should -Be '58m'
            Format-Duration 3520 | Should -Be '59m'
        }
    }

    Context "hours" {
        It "1dp from 3600s to 86400s" {
            Format-Duration 3600 | Should -Be '1.0h'
            Format-Duration 3900 | Should -Be '1.1h'
            Format-Duration 5400 | Should -Be '1.5h'
        }
    }

    Context "days" {
        It "1dp at 86400s and above" {
            Format-Duration 86400  | Should -Be '1.0d'
            Format-Duration 172800 | Should -Be '2.0d'
        }
    }
}
