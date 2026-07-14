BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $scriptToTest "dummyPath" 7
}

Describe "FilenameIsDeletionCandidate" {
    It "Retains the report file" {
        $reportFile = "report.txt"
        FilenameIsDeletionCandidate "report.txt" $reportFile | Should -Be $false
        FilenameIsDeletionCandidate "foo" $reportFile | Should -Be $true
        FilenameIsDeletionCandidate "myReport.txt" $reportFile | Should -Be $true
    }
    It "Optionally matches a set of files" {
        $reportFile = "report.txt"
        FilenameIsDeletionCandidate "foo.ps1" $reportFile '\.gif$' | Should -Be $false
        FilenameIsDeletionCandidate "foo.gif" $reportFile '\.gif$' | Should -Be $true
    }
}

Describe "GetDeletionReport" {
    It "Summarizes what it last did" {
        GetDeletionReport 5 '\.png$' "2023-10-01" | Should -Be @(
            "5 days",
            "Only filenames matching Powershell regex: \.png$",
            "",
            "Last run: 2023-10-01"
        )
    }
}

Describe "Delete-OldFiles" {
    Context "Early errors" {
        It "Throws various errors" {
            { &$scriptToTest -RetentionDays 7 } 
                | Should -Throw "path parameter is required"
            { &$scriptToTest -Path $PWD } 
                | Should -Throw "retentionDays parameter is required"
        }
    }
    Context "Need test root" {
        BeforeAll {
            $testRoot = "TestDrive:\\Delete-OldFiles.Tests"
            New-Item -Path $testRoot -ItemType Directory | Out-Null

            function CreateDir($path, $creationTime = $null) {
                mkdir $path | Out-Null
                if ($null -ne $creationTime) {
                    Get-Item $path | Set-ItemProperty -Name CreationTime -Value $creationTime
                }
            }

            function CreateFile($path, $creationTime = $null) {
                New-Item -Path $path -ItemType File -Value "test" | Out-Null
                if ($null -ne $creationTime) {
                    Get-Item $path | Set-ItemProperty -Name CreationTime -Value $creationTime
                }
            }

            # Shadows icacls.exe so access-grant attempts never touch real ACLs (tests Mock this).
            function icacls { }
        }
        BeforeEach {
            $now = Get-Date
            $past = $now.AddDays(-8)
            Push-Location $testRoot
            Mock Get-Date { $now }
            Mock icacls { }
        }
        AfterEach {
            Pop-Location
            Get-ChildItem $testRoot | Remove-Item -Recurse -Force
        }
        AfterAll {
            Remove-Item $testRoot -Recurse -Force
        }
        It "Deletes files older than the retention period" {
            @("p1", "p1\c", "p2") | ForEach-Object { CreateDir $_ }
            CreateDir "p2\c" $past
            @("p3", "p3\c") | ForEach-Object { CreateDir $_ }
            CreateFile "p1\c\a.txt" $past
            CreateFile "p1\c\a.bar" $past
            CreateFile "p2\c\b.txt" $past
            CreateFile "p2\d.txt"
            CreateFile "p3\c\b.txt" $past

            &$scriptToTest -Path $testRoot -RetentionDays 7  -OptionalFilenameMatch '\.txt$' 6>&1 | Out-Null

            Test-Path "p1\c\a.txt" | Should -Be $false
            Test-Path "p1\c\a.bar" | Should -Be $true
            Test-Path "p2\c" | Should -Be $false
            Test-Path "p2\d.txt" | Should -Be $true
            Test-Path "p3\c\b.txt" | Should -Be $false
            Test-Path "p3\c" | Should -Be $true
            Test-Path "$testRoot\deletion_report.txt" | Should -Be $true
        }
        It "Retries a denied deletion after granting access, without warning" {
            CreateDir "pr"
            CreateFile "pr\flaky.txt" $past
            # First call throws (simulated access-denied); the retry after the grant "succeeds" (no-op).
            # $global: because MockWith bodies don't share this file's $script: scope.
            $global:denyOnce = $true
            Mock Remove-Item -ParameterFilter { "$Path" -like '*flaky.txt' } -MockWith {
                if ($global:denyOnce) { $global:denyOnce = $false; throw [System.UnauthorizedAccessException]::new("Access is denied.") }
            }

            $output = &$scriptToTest -Path $testRoot -RetentionDays 7 *>&1

            Should -Invoke Remove-Item -Times 2 -Exactly -ParameterFilter { "$Path" -like '*flaky.txt' }
            Should -Invoke icacls -Times 1 -Exactly
            @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Count | Should -Be 0
            Remove-Variable denyOnce -Scope Global -ErrorAction SilentlyContinue
        }

        It "Warns when deletion fails even after granting access" {
            CreateDir "pw"
            CreateFile "pw\stuck.txt" $past
            Mock Remove-Item -ParameterFilter { "$Path" -like '*stuck.txt' } -MockWith {
                throw [System.UnauthorizedAccessException]::new("Access is denied.")
            }

            $output = &$scriptToTest -Path $testRoot -RetentionDays 7 *>&1

            Test-Path "pw\stuck.txt" | Should -Be $true
            $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $warnings.Count | Should -Be 1
            "$($warnings[0])" | Should -BeLike '*stuck.txt*'
        }

        It "RemoveOldFiles returns the paths it could not delete and deletes the rest" {
            CreateDir "pd"
            CreateFile "pd\denied.txt" $past
            CreateFile "pd\ok.txt" $past
            Mock Remove-Item -ParameterFilter { "$Path" -like '*denied.txt' } -MockWith {
                throw [System.UnauthorizedAccessException]::new("Access is denied.")
            }

            $failed = @(RemoveOldFiles "$testRoot\pd" ($now.AddDays(-7)) "deletion_report.txt" "")

            $failed.Count | Should -Be 1
            $failed[0] | Should -BeLike '*denied.txt'
            Test-Path "pd\ok.txt" | Should -Be $false
            Test-Path "pd\denied.txt" | Should -Be $true
        }

        It "Ignores non-container paths" {
            $subRoot = "$testRoot\foo"
            New-Item -Path $subRoot -ItemType File -Value "test" | Out-Null

            $writtenToHost = &$scriptToTest -Path $subRoot -RetentionDays 7 6>&1

            Test-Path $subRoot | Should -Be $true
            $writtenToHost.Count | Should -Be 1
            $writtenToHost[0] | Should -Be "Ignoring: $subRoot"
        }
        It "Ignores non-existent paths" {
            $subRoot = "$testRoot\foo2"
            Test-Path $subRoot | Should -Be $false

            $writtenToHost = &$scriptToTest -Path $subRoot -RetentionDays 7 6>&1

            $writtenToHost.Count | Should -Be 1
            $writtenToHost[0] | Should -Be "Ignoring: $subRoot"
        }
    }
}   
