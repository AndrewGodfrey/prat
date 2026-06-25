BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    function isAbsent($name) {
        return -not [System.Environment]::GetEnvironmentVariables().ContainsKey($name)
    }
}

Describe "envTemp" {
    BeforeEach {
        Remove-Item 'env:_prat_envTemp_1' -ErrorAction SilentlyContinue
        Remove-Item 'env:_prat_envTemp_2' -ErrorAction SilentlyContinue
        Remove-Item 'env:_prat_envTemp_3' -ErrorAction SilentlyContinue
    }
    AfterEach {
        Remove-Item 'env:_prat_envTemp_1' -ErrorAction SilentlyContinue
        Remove-Item 'env:_prat_envTemp_2' -ErrorAction SilentlyContinue
        Remove-Item 'env:_prat_envTemp_3' -ErrorAction SilentlyContinue
    }

    Context "Save-Env" {
        It "returns null for a variable that is not set" {
            $token = Save-Env @('_prat_envTemp_1')
            $token['_prat_envTemp_1'] | Should -BeNull
        }

        It "returns current value for a variable that is set" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "hello")
            $token = Save-Env @('_prat_envTemp_1')
            $token['_prat_envTemp_1'] | Should -Be "hello"
        }

        It "does not modify any variables" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "unchanged")
            Save-Env @('_prat_envTemp_1') | Out-Null
            [System.Environment]::GetEnvironmentVariable('_prat_envTemp_1') | Should -Be "unchanged"
        }

        It "saves multiple variables" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "aaa")
            $token = Save-Env @('_prat_envTemp_1', '_prat_envTemp_2')
            $token['_prat_envTemp_1'] | Should -Be "aaa"
            $token['_prat_envTemp_2'] | Should -BeNull
        }
    }

    Context "Set-EnvTemp" {
        It "sets a variable and returns the old value in the token" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "old")
            $token = Set-EnvTemp @{ '_prat_envTemp_1' = "new" }
            [System.Environment]::GetEnvironmentVariable('_prat_envTemp_1') | Should -Be "new"
            $token['_prat_envTemp_1'] | Should -Be "old"
        }

        It "saves null in token when variable did not exist before" {
            $token = Set-EnvTemp @{ '_prat_envTemp_1' = "new" }
            $token['_prat_envTemp_1'] | Should -BeNull
        }

        It "makes the variable absent (not empty string) when value is null" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "existing")
            Set-EnvTemp @{ '_prat_envTemp_1' = $null } | Out-Null
            isAbsent '_prat_envTemp_1' | Should -BeTrue
        }

        It "makes the variable present when value is empty string" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "existing")
            Set-EnvTemp @{ '_prat_envTemp_1' = "" } | Out-Null
            isAbsent '_prat_envTemp_1' | Should -BeFalse
        }

        It "sets multiple variables" {
            $token = Set-EnvTemp @{ '_prat_envTemp_1' = "aaa"; '_prat_envTemp_2' = "bbb" }
            [System.Environment]::GetEnvironmentVariable('_prat_envTemp_1') | Should -Be "aaa"
            [System.Environment]::GetEnvironmentVariable('_prat_envTemp_2') | Should -Be "bbb"
            $token['_prat_envTemp_1'] | Should -BeNull
            $token['_prat_envTemp_2'] | Should -BeNull
        }
    }

    Context "Restore-Env" {
        It "restores a variable to its previous value" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "changed")
            Restore-Env @{ '_prat_envTemp_1' = "original" }
            [System.Environment]::GetEnvironmentVariable('_prat_envTemp_1') | Should -Be "original"
        }

        It "makes the variable absent when token value is null" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "set")
            Restore-Env @{ '_prat_envTemp_1' = $null }
            isAbsent '_prat_envTemp_1' | Should -BeTrue
        }

        It "makes the variable present when token value is empty string" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "set")
            Restore-Env @{ '_prat_envTemp_1' = "" }
            isAbsent '_prat_envTemp_1' | Should -BeFalse
        }

        It "restores multiple variables" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "changed1")
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_2', "changed2")
            Restore-Env @{ '_prat_envTemp_1' = "orig1"; '_prat_envTemp_2' = $null }
            [System.Environment]::GetEnvironmentVariable('_prat_envTemp_1') | Should -Be "orig1"
            isAbsent '_prat_envTemp_2' | Should -BeTrue
        }
    }

    Context "Set-EnvTemp + Restore-Env" {
        It "round-trips a variable back to its original value" {
            [System.Environment]::SetEnvironmentVariable('_prat_envTemp_1', "original")
            $token = Set-EnvTemp @{ '_prat_envTemp_1' = "temp" }
            Restore-Env $token
            [System.Environment]::GetEnvironmentVariable('_prat_envTemp_1') | Should -Be "original"
        }

        It "makes the variable absent after restore if it was not set before" {
            $token = Set-EnvTemp @{ '_prat_envTemp_1' = "temp" }
            Restore-Env $token
            isAbsent '_prat_envTemp_1' | Should -BeTrue
        }
    }
}
