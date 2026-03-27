BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Initialize-TestRunDir" {
    It "creates last/ directory and returns its path" {
        $outputDir = "$TestDrive/run1"
        New-Item $outputDir -ItemType Directory | Out-Null

        $result = Initialize-TestRunDir -OutputDir $outputDir

        $result | Should -Be "$outputDir/last"
        "$outputDir/last" | Should -Exist
    }

    It "rotates existing last/ to a timestamped directory" {
        $outputDir = "$TestDrive/rotate1"
        New-Item $outputDir -ItemType Directory | Out-Null

        Initialize-TestRunDir -OutputDir $outputDir | Out-Null
        Initialize-TestRunDir -OutputDir $outputDir -Timestamp "2000-01-01T00-00-00-001" | Out-Null

        "$outputDir/2000-01-01T00-00-00-001" | Should -Exist
        "$outputDir/last" | Should -Exist
    }

    It "applies retention: removes oldest dirs beyond N" {
        $outputDir = "$TestDrive/retention1"
        New-Item $outputDir -ItemType Directory | Out-Null

        # Run 4 times: creates ts-001, ts-002, ts-003 then 'last'.
        # With N=2 on run 4: 3 timestamp dirs > 2 limit, ts-001 pruned.
        Initialize-TestRunDir -OutputDir $outputDir | Out-Null
        Initialize-TestRunDir -OutputDir $outputDir -Timestamp "ts-001" | Out-Null
        Initialize-TestRunDir -OutputDir $outputDir -Timestamp "ts-002" | Out-Null
        Initialize-TestRunDir -OutputDir $outputDir -Timestamp "ts-003" -Retention 2 | Out-Null

        "$outputDir/ts-001" | Should -Not -Exist
        "$outputDir/ts-002" | Should -Exist
        "$outputDir/ts-003" | Should -Exist
    }

    It "does not prune when at or below retention limit" {
        $outputDir = "$TestDrive/retention-ok"
        New-Item $outputDir -ItemType Directory | Out-Null

        Initialize-TestRunDir -OutputDir $outputDir | Out-Null
        Initialize-TestRunDir -OutputDir $outputDir -Timestamp "ts-001" -Retention 2 | Out-Null

        "$outputDir/ts-001" | Should -Exist
    }
}

Describe "Format-AnsiText" {
    It "wraps text in ANSI escape codes" {
        Format-AnsiText -Text "hello" -ColorCode 92 | Should -Be "`e[92mhello`e[0m"
    }

    It "accepts different color codes" {
        Format-AnsiText -Text "warn" -ColorCode 91 | Should -Be "`e[91mwarn`e[0m"
    }
}
