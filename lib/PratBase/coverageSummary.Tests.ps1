BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Format-CoverageData" {
    It "returns null for null data" {
        Format-CoverageData $null | Should -BeNullOrEmpty
    }

    It "formats a coverage data hashtable as a summary string" {
        $data = @{ Pct = 75; Target = 70; Covered = 150; Total = 200; Unit = "commands"; FileCount = 10 }
        Format-CoverageData $data | Should -Be "Covered 75% / 70%. 150/200 commands in 10 Files."
    }
}

Describe "Get-CoverageSummary" {
    BeforeAll {
        Mock Get-CoveragePercentTarget -ModuleName PratBase { return 70 }
    }

    It "returns null for null path" {
        Get-CoverageSummary -Path $null | Should -BeNullOrEmpty
    }

    It "returns null for non-existent file" {
        Get-CoverageSummary -Path "$TestDrive/nonexistent.xml" | Should -BeNullOrEmpty
    }

    It "parses JaCoCo format: returns Covered, Total, FileCount, Pct, Unit, Target" {
        $f = "$TestDrive/gcd-jacoco.xml"
        @"
<?xml version="1.0"?>
<report name="test">
  <counter type="INSTRUCTION" missed="50" covered="150" />
  <counter type="CLASS" missed="2" covered="8" />
</report>
"@ | Set-Content $f -Encoding utf8NoBOM

        $result = Get-CoverageSummary -Path $f -CoverageUnitForJaCoco 'commands'

        $result.Covered   | Should -Be 150
        $result.Total     | Should -Be 200
        $result.FileCount | Should -Be 10
        $result.Pct       | Should -Be 75.0
        $result.Unit      | Should -Be "commands"
        $result.Target    | Should -Be 70
    }

    It "parses Cobertura format: returns Covered, Total, FileCount, Pct, Unit, Target" {
        $f = "$TestDrive/gcd-cobertura.xml"
        @"
<?xml version="1.0"?>
<coverage line-rate="0.85" lines-covered="85" lines-valid="100">
  <packages><package name="p">
    <classes>
      <class filename="Foo.cs" />
      <class filename="Bar.cs" />
      <class filename="Baz.cs" />
    </classes>
  </package></packages>
</coverage>
"@ | Set-Content $f -Encoding utf8NoBOM

        $result = Get-CoverageSummary -Path $f

        $result.Covered   | Should -Be 85
        $result.Total     | Should -Be 100
        $result.FileCount | Should -Be 3
        $result.Pct       | Should -Be 85.0
        $result.Unit      | Should -Be "lines"
        $result.Target    | Should -Be 70
    }

    It "returns null for JaCoCo with zero instruction total" {
        $f = "$TestDrive/gcd-jacoco-zero.xml"
        @"
<?xml version="1.0"?>
<report name="test">
  <counter type="INSTRUCTION" missed="0" covered="0" />
  <counter type="CLASS" missed="0" covered="0" />
</report>
"@ | Set-Content $f -Encoding utf8NoBOM

        Get-CoverageSummary -Path $f -CoverageUnitForJaCoco 'commands' | Should -BeNullOrEmpty
    }

    It "parses Cobertura format: uses branch coverage when branches-valid > 0" {
        $f = "$TestDrive/gcd-cobertura-branch.xml"
        @"
<?xml version="1.0"?>
<coverage line-rate="0.85" lines-covered="85" lines-valid="100" branch-rate="0.60" branches-covered="30" branches-valid="50">
  <packages><package name="p">
    <classes>
      <class filename="Foo.cs" />
    </classes>
  </package></packages>
</coverage>
"@ | Set-Content $f -Encoding utf8NoBOM

        $result = Get-CoverageSummary -Path $f

        $result.Covered   | Should -Be 30
        $result.Total     | Should -Be 50
        $result.FileCount | Should -Be 1
        $result.Pct       | Should -Be 60.0
        $result.Unit      | Should -Be "branches"
        $result.Target    | Should -Be 70
    }

    It "Cobertura: throws when CoverageUnitForJaCoco is supplied (unit is derived from XML)" {
        $f = "$TestDrive/gcd-cobertura-unit-err.xml"
        @"
<?xml version="1.0"?>
<coverage line-rate="0.85" lines-covered="85" lines-valid="100">
  <packages><package name="p">
    <classes>
      <class filename="Foo.cs" />
    </classes>
  </package></packages>
</coverage>
"@ | Set-Content $f -Encoding utf8NoBOM

        { Get-CoverageSummary -Path $f -CoverageUnitForJaCoco 'commands' } | Should -Throw "*CoverageUnitForJaCoco*"
    }

    It "returns null for Cobertura with zero lines-valid" {
        $f = "$TestDrive/gcd-zero.xml"
        @"
<?xml version="1.0"?>
<coverage line-rate="0" lines-covered="0" lines-valid="0">
  <packages><package name="p"><classes></classes></package></packages>
</coverage>
"@ | Set-Content $f -Encoding utf8NoBOM

        Get-CoverageSummary -Path $f | Should -BeNullOrEmpty
    }

    It "returns null for empty XML file (no root element)" {
        $f = "$TestDrive/gcd-empty.xml"
        "" | Set-Content $f -Encoding utf8NoBOM

        Get-CoverageSummary -Path $f | Should -BeNullOrEmpty
    }

    It "throws for unrecognized XML root element" {
        $f = "$TestDrive/gcd-unknown.xml"
        @"
<?xml version="1.0"?>
<summary foo="bar" />
"@ | Set-Content $f -Encoding utf8NoBOM

        { Get-CoverageSummary -Path $f } | Should -Throw -ExpectedMessage "*unrecognized*"
    }
}
