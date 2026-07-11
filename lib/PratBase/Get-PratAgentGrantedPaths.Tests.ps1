BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-PratAgentGrantedPaths" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testProfilePath = "$root/codebaseProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    It "returns an rw-granted repo's root under .rw" {
        "@{ '.' = @{ repos = @{ r = @{ grantAgentAccess = 'rw' } } } }" | Out-File $testProfilePath

        $result = Get-PratAgentGrantedPaths

        $result.rw | Should -Be @("$root/r")
        $result.read | Should -BeNullOrEmpty
    }

    It "returns a read-granted repo's root under .read" {
        "@{ '.' = @{ repos = @{ r = @{ grantAgentAccess = 'read' } } } }" | Out-File $testProfilePath

        $result = Get-PratAgentGrantedPaths

        $result.read | Should -Be @("$root/r")
        $result.rw | Should -BeNullOrEmpty
    }

    It "excludes a repo with no grantAgentAccess field" {
        "@{ '.' = @{ repos = @{ r = @{} } } }" | Out-File $testProfilePath

        $result = Get-PratAgentGrantedPaths

        $result.rw | Should -BeNullOrEmpty
        $result.read | Should -BeNullOrEmpty
    }

    It "excludes a subproject's own path even though it inherits grantAgentAccess from its parent" {
        "@{ '.' = @{ repos = @{ r = @{ grantAgentAccess = 'rw'; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath

        $result = Get-PratAgentGrantedPaths

        $result.rw | Should -Be @("$root/r")
    }

    It "aggregates multiple repos across grant levels, sorted" {
        "@{ '.' = @{ repos = @{ rB = @{ grantAgentAccess = 'rw' }; rA = @{ grantAgentAccess = 'rw' }; rd = @{ grantAgentAccess = 'read' }; unset = @{} } } }" | Out-File $testProfilePath

        $result = Get-PratAgentGrantedPaths

        $result.rw | Should -Be @("$root/rA", "$root/rB")
        $result.read | Should -Be @("$root/rd")
    }

    It "returns empty rw/read arrays when no repoProfile files are registered" {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @() }

        $result = Get-PratAgentGrantedPaths

        $result.rw | Should -BeNullOrEmpty
        $result.read | Should -BeNullOrEmpty
    }
}
