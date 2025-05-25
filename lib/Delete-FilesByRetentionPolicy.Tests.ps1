BeforeAll {
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $scriptToTest "dummyPath" 7
}

Describe "FilenameIsUnderRetention" {
    It "Retains the report file" {
        $reportFile = "report.txt"
        FilenameIsUnderRetention "report.txt" $reportFile | Should -Be $false
        FilenameIsUnderRetention "foo" $reportFile | Should -Be $true
        FilenameIsUnderRetention "myReport.txt" $reportFile | Should -Be $true
    }
    It "Optionally matches a set of files" {
        $reportFile = "report.txt"
        FilenameIsUnderRetention "foo.ps1" $reportFile '\.gif$' | Should -Be $false
        FilenameIsUnderRetention "foo.gif" $reportFile '\.gif$' | Should -Be $true
    }
}

Describe "GetReport" {
    It "Summarizes what it last did" {
        GetReport 5 '\.png$' "2023-10-01" | Should -Be @(
            "5 days",
            "Only filenames matching Powershell regex: \.png$",
            "",
            "Last run: 2023-10-01"
        )
    }
}

Describe "Delete-FilesByRetentionPolicy" {
    Context "Early errors" {
        It "Throws various errors" {
            { &$scriptToTest -RetentionDays 7 } 
                | Should -Throw "path parameter is required"
            { &$scriptToTest -Path $PWD } 
                | Should -Throw "retentionDays parameter is required"
        }
    }
    Context "Need test root" {
        BeforeEach {
            $testRoot = "TestDrive:\Delete-FilesByRetentionPolicy.Tests"
            $now = Get-Date
            $past = $now.AddDays(-8)
            Mock Get-Date { $now }

            function CreateDir($path, $creationTime) {
                mkdir $path | Out-Null
                Get-Item $path | Set-ItemProperty -Name CreationTime -Value $creationTime
            }

            function CreateFile($path, $creationTime) {
                New-Item -Path $path -ItemType File -Value "test" | Out-Null
                Get-Item $path | Set-ItemProperty -Name CreationTime -Value $creationTime
            }

            CreateDir $testRoot $past
            Push-Location $testRoot
        }
        AfterEach {
            Pop-Location
            Remove-Item $testRoot -Recurse -Force
        }
        It "Deletes files older than the retention period" {
            @("p1", "p1\c", "p2", "p2\c") | ForEach-Object { CreateDir $_ $past }
            @("p3", "p3\c") | ForEach-Object { CreateDir $_ $now }
            CreateFile "p1\c\a.txt" $past
            CreateFile "p1\c\a.bar" $past
            CreateFile "p2\c\b.txt" $past
            CreateFile "p2\d.txt" $now
            CreateFile "p3\c\b.txt" $past

            &$scriptToTest -Path $testRoot -RetentionDays 7  -OptionalFilenameMatch '\.txt$' 6>&1 | Out-Null

            Test-Path "p1\c\a.txt" | Should -Be $false
            Test-Path "p1\c\a.bar" | Should -Be $true
            Test-Path "p2\c" | Should -Be $false
            Test-Path "p2\d.txt" | Should -Be $true
            Test-Path "p3\c\b.txt" | Should -Be $false
            Test-Path "p3\c" | Should -Be $true
            Test-Path "$testRoot\retentionpolicy.txt" | Should -Be $true
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

