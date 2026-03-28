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

Describe "Write-TestRunResult" {
    It "builds and writes summary.txt from components" {
        $runDir = "$TestDrive/wr-write"
        New-Item $runDir -ItemType Directory | Out-Null

        Write-TestRunResult -Passed 10 -Failed 0 -RunDir $runDir

        "$runDir/summary.txt" | Should -Exist
        Get-Content "$runDir/summary.txt" | Should -Match "Passed: 10, Failed: 0\."
    }

    It "prepends coverage summary when provided" {
        $runDir = "$TestDrive/wr-coverage"
        New-Item $runDir -ItemType Directory | Out-Null

        $output = Write-TestRunResult -CoverageSummary "Covered 85% / 70%. 17/20 Lines in 3 Files." `
            -Passed 5 -Failed 0 -RunDir $runDir

        $summary = Get-Content "$runDir/summary.txt"
        $summary | Should -Match "Covered 85%"
        $summary | Should -Match "Passed: 5"
    }

    It "emits green for all-pass, yellow for partial failures, red for mass failures" {
        $runDir1 = "$TestDrive/wr-green"; New-Item $runDir1 -ItemType Directory | Out-Null
        $runDir2 = "$TestDrive/wr-yellow"; New-Item $runDir2 -ItemType Directory | Out-Null
        $runDir3 = "$TestDrive/wr-red"; New-Item $runDir3 -ItemType Directory | Out-Null

        $green  = Write-TestRunResult -Passed 3 -Failed 0 -RunDir $runDir1
        $yellow = Write-TestRunResult -Passed 0 -Failed 3 -RunDir $runDir2
        $red    = Write-TestRunResult -Passed 0 -Failed 5 -RunDir $runDir3 -FailureThreshold 5

        $green  | Select-Object -First 1 | Should -Match '^\x1b\[92m'
        $yellow | Select-Object -First 1 | Should -Match '^\x1b\[93m'
        $red    | Select-Object -First 1 | Should -Match '^\x1b\[91m'
    }

    It "emits yellow and fallback text when result is null" {
        $runDir = "$TestDrive/wr-null"
        New-Item $runDir -ItemType Directory | Out-Null

        $output = Write-TestRunResult -RunDir $runDir

        $output | Select-Object -First 1 | Should -Match '^\x1b\[93m'
        Get-Content "$runDir/summary.txt" | Should -Match "no result parsed"
    }

    It "emits suppressed hint when some failures were suppressed" {
        $runDir = "$TestDrive/wr-suppressed"
        New-Item $runDir -ItemType Directory | Out-Null

        $output = Write-TestRunResult -Passed 0 -Failed 7 -FailuresSeen 5 -RunDir $runDir

        $output | Where-Object { $_ -match '2 failures suppressed' } | Should -Not -BeNullOrEmpty
        $output | Where-Object { $_ -match 'test-run\.txt' } | Should -Not -BeNullOrEmpty
    }

    It "emits 'See logfile' hint (no suppressed count) when all failures were shown" {
        $runDir = "$TestDrive/wr-all-shown"
        New-Item $runDir -ItemType Directory | Out-Null

        $output = Write-TestRunResult -Passed 0 -Failed 3 -FailuresSeen 3 -RunDir $runDir

        $output | Where-Object { $_ -match '^.*See.*test-run\.txt' } | Should -Not -BeNullOrEmpty
        $output | Where-Object { $_ -match 'suppressed' } | Should -BeNullOrEmpty
    }

    It "emits red, fatal error in summary.txt, log tail, and See-logfile hint when FatalError is set" {
        $runDir = "$TestDrive/wr-fatal"
        New-Item $runDir -ItemType Directory | Out-Null
        1..30 | ForEach-Object { "line $_" } | Set-Content "$runDir/test-run.txt" -Encoding utf8NoBOM

        $output = Write-TestRunResult -FatalError "exit code: 1" -RunDir $runDir

        $output | Select-Object -First 1 | Should -Match '^\x1b\[91m'
        $summary = Get-Content "$runDir/summary.txt"
        $summary | Should -Match "exit code: 1"
        $summary | Should -Match "no result parsed"
        $output | Where-Object { $_ -match 'line 30' } | Should -Not -BeNullOrEmpty
        $output | Where-Object { $_ -match 'line 10$' } | Should -BeNullOrEmpty  # beyond tail -20
        $output | Where-Object { $_ -match 'test-run\.txt' } | Should -Not -BeNullOrEmpty
    }

    It "emits no hint when Failed is 0" {
        $runDir = "$TestDrive/wr-no-hint"
        New-Item $runDir -ItemType Directory | Out-Null

        $output = Write-TestRunResult -Passed 5 -Failed 0 -RunDir $runDir

        $output | Where-Object { $_ -match 'test-run\.txt' } | Should -BeNullOrEmpty
    }

    It "emits no hint when -Debugging" {
        $runDir = "$TestDrive/wr-debug"
        New-Item $runDir -ItemType Directory | Out-Null

        $output = Write-TestRunResult -Passed 0 -Failed 3 -FailuresSeen 3 -RunDir $runDir -Debugging

        $output | Where-Object { $_ -match 'test-run\.txt' } | Should -BeNullOrEmpty
    }

    It "normalizes backslashes to forward slashes in log file hint path" {
        $runDir = "$TestDrive/wr-slash"
        New-Item $runDir -ItemType Directory | Out-Null

        $output = Write-TestRunResult -Passed 0 -Failed 1 -FailuresSeen 1 -RunDir ($runDir -replace '/', '\')

        $hint = $output | Where-Object { $_ -match 'test-run\.txt' }
        $hint | Should -Not -Match '\\'
    }
}

Describe "Convert-CoberturaXmlFile" {
    BeforeAll {
        function makeCoberturaFile($path, $sources, $filenames) {
            $sourcesXml = if ($sources) {
                $inner = ($sources | ForEach-Object { "<source>$_</source>" }) -join ''
                "<sources>$inner</sources>"
            } else { "" }
            $classesXml = ($filenames | ForEach-Object {
                $fn = $_
                "<class filename=""$fn"" />"
            }) -join ''
            @"
<?xml version="1.0"?>
<coverage line-rate="0.8" lines-covered="8" lines-valid="10">
  $sourcesXml
  <packages><package name="p"><classes>$classesXml</classes></package></packages>
</coverage>
"@ | Set-Content $path -Encoding utf8NoBOM
        }
    }

    It "adds a sources element pointing to '.' when missing" {
        $f = "$TestDrive/cov-nosources.xml"
        makeCoberturaFile $f $null @("Q:/src/Foo/Bar.cs")

        Convert-CoberturaXmlFile -Path $f

        [xml]$xml = Get-Content $f
        $xml.coverage.sources.source | Should -Be "."
    }

    It "does not modify existing <sources> element" {
        $f = "$TestDrive/cov-hassources.xml"
        makeCoberturaFile $f @("Q:/") @("src/Foo/Bar.cs")

        Convert-CoberturaXmlFile -Path $f

        [xml]$xml = Get-Content $f
        $xml.coverage.sources.source | Should -Be "Q:/"
    }

    It "strips matching path prefix from filename attributes" {
        $f = "$TestDrive/cov-prefix.xml"
        makeCoberturaFile $f $null @("Q:/src/MyProject/Foo/Bar.cs", "Q:/src/MyProject/Baz/Qux.cs")

        Convert-CoberturaXmlFile -Path $f -PathPrefixes @("Q:/src/MyProject")

        [xml]$xml = Get-Content $f
        $classes = $xml.coverage.packages.package.classes.class
        $classes[0].filename | Should -Be "Foo/Bar.cs"
        $classes[1].filename | Should -Be "Baz/Qux.cs"
    }

    It "strips prefix from relative filenames by joining with source element (coverlet case)" {
        $f = "$TestDrive/cov-coverlet.xml"
        makeCoberturaFile $f @("Q:/") @("src/MyProject/Foo/Bar.cs", "src/MyProject/Baz/Qux.cs")

        Convert-CoberturaXmlFile -Path $f -PathPrefixes @("Q:/src/MyProject")

        [xml]$xml = Get-Content $f
        $classes = $xml.coverage.packages.package.classes.class
        $classes[0].filename | Should -Be "Foo/Bar.cs"
        $classes[1].filename | Should -Be "Baz/Qux.cs"
    }

    It "throws when multiple source elements are present" {
        $f = "$TestDrive/cov-multisource.xml"
        makeCoberturaFile $f @("Q:/", "C:/") @("src/Foo.cs")

        { Convert-CoberturaXmlFile -Path $f } | Should -Throw -ExpectedMessage "*multiple*"
    }

    It "leaves filenames that don't match any prefix unchanged" {
        $f = "$TestDrive/cov-nomatch.xml"
        makeCoberturaFile $f $null @("Q:/src/Other/Foo.cs")

        Convert-CoberturaXmlFile -Path $f -PathPrefixes @("Q:/src/MyProject")

        [xml]$xml = Get-Content $f
        $xml.coverage.packages.package.classes.class.filename | Should -Be "Q:/src/Other/Foo.cs"
    }
}

Describe "Get-PathPrefixesFromWorkspace" {
    It "returns absolute folder paths from a .code-workspace file" {
        $dir1 = "$TestDrive/ws-abs1"; New-Item $dir1 -ItemType Directory | Out-Null
        $dir2 = "$TestDrive/ws-abs2"; New-Item $dir2 -ItemType Directory | Out-Null
        $f = "$TestDrive/test.code-workspace"
        $p1 = $dir1 -replace '\\', '/'; $p2 = $dir2 -replace '\\', '/'
        "{ `"folders`": [{ `"path`": `"$p1`" }, { `"path`": `"$p2`" }] }" | Set-Content $f -Encoding utf8NoBOM

        $result = Get-PathPrefixesFromWorkspace -WorkspaceFile $f

        $result[0] | Should -Be ((Resolve-Path $dir1).Path -replace '\\', '/')
        $result[1] | Should -Be ((Resolve-Path $dir2).Path -replace '\\', '/')
    }

    It "returns empty array when folders is empty" {
        $f = "$TestDrive/empty.code-workspace"
        '{ "folders": [] }' | Set-Content $f -Encoding utf8NoBOM

        $result = Get-PathPrefixesFromWorkspace -WorkspaceFile $f

        $result | Should -BeNullOrEmpty
    }

    It "resolves relative folder paths to absolute using the workspace file's location" {
        $dir = "$TestDrive/ws"
        New-Item $dir -ItemType Directory | Out-Null
        New-Item "$TestDrive/sibling" -ItemType Directory | Out-Null
        $f = "$dir/my.code-workspace"
        '{ "folders": [{ "path": "." }, { "path": "../sibling" }] }' | Set-Content $f -Encoding utf8NoBOM

        $result = Get-PathPrefixesFromWorkspace -WorkspaceFile $f

        $result[0] | Should -Be ((Resolve-Path "$dir").Path -replace '\\', '/')
        $result[1] | Should -Be ((Resolve-Path "$TestDrive/sibling").Path -replace '\\', '/')
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
