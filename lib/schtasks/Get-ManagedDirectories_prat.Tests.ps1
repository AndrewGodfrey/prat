BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe "Get-ManagedDirectories_prat" {
    It "always includes prat's own auto/log at 14 days" {
        $result = @(& $scriptToTest)

        $result | Should -HaveCount 1
        $result[0].path | Should -BeLike "*prat\auto\log"
        $result[0].days | Should -Be 14
    }

    It "adds nothing else without -AddRecommendedDirectories" {
        $result = @(& $scriptToTest -UserName 'someone')

        $result | Should -HaveCount 1
    }

    It "adds the recommended entries under -AddRecommendedDirectories, for a UserName whose agent-temp dir doesn't exist" {
        $result = @(& $scriptToTest -AddRecommendedDirectories -UserName 'no-such-user-xyz')

        # 1 (auto/log) + 5 (symbol caches) + Downloads + C:\tmp + $env:temp = 9; no agent-temp entry
        $result | Should -HaveCount 9
        ($result | Where-Object { $_.path -like '*Downloads*' }) | Should -HaveCount 1
        ($result | Where-Object { $_.path -eq 'C:\tmp' }) | Should -HaveCount 1
        ($result | Where-Object { $_.path -eq $env:temp }) | Should -HaveCount 1
    }

    It "adds a 14-day entry for <UserName>_agent's temp dir when that directory exists" {
        Mock Test-Path { $true } -ParameterFilter { $Path -eq "C:\Users\someone_agent\AppData\Local\Temp" }

        $result = @(& $scriptToTest -AddRecommendedDirectories -UserName 'someone')

        $agentEntry = $result | Where-Object { $_.path -eq "C:\Users\someone_agent\AppData\Local\Temp" }
        $agentEntry | Should -HaveCount 1
        $agentEntry.days | Should -Be 14
    }

    It "defaults UserName to the current user, so it's self-sufficient when called standalone" {
        Mock Test-Path { $true } -ParameterFilter { $Path -eq "C:\Users\${env:USERNAME}_agent\AppData\Local\Temp" }

        $result = @(& $scriptToTest -AddRecommendedDirectories)

        ($result | Where-Object { $_.path -eq "C:\Users\${env:USERNAME}_agent\AppData\Local\Temp" }) | Should -HaveCount 1
    }
}