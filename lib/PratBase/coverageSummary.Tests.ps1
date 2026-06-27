BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Format-CoverageData" {
    It "returns null for null data" {
        Format-CoverageData $null | Should -BeNullOrEmpty
    }

    It "formats a coverage data hashtable as a summary string" {
        $data = @{ Pct = 75; Target = 70; Covered = 150; Total = 200; Unit = "Commands"; FileCount = 10 }
        Format-CoverageData $data | Should -Be "Covered 75% / 70%. 150/200 Commands in 10 Files."
    }
}

Describe "Get-CoverageData" {
    BeforeAll {
        Mock Get-CoveragePercentTarget -ModuleName PratBase { return 70 }
    }

    It "returns null for null path" {
        Get-CoverageData -Path $null -Unit "Commands" | Should -BeNullOrEmpty
    }

    It "returns null for non-existent file" {
        Get-CoverageData -Path "$TestDrive/nonexistent.xml" -Unit "Commands" | Should -BeNullOrEmpty
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

        $result = Get-CoverageData -Path $f -Unit "Commands"

        $result.Covered   | Should -Be 150
        $result.Total     | Should -Be 200
        $result.FileCount | Should -Be 10
        $result.Pct       | Should -Be 75.0
        $result.Unit      | Should -Be "Commands"
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

        $result = Get-CoverageData -Path $f -Unit "Lines"

        $result.Covered   | Should -Be 85
        $result.Total     | Should -Be 100
        $result.FileCount | Should -Be 3
        $result.Pct       | Should -Be 85.0
        $result.Unit      | Should -Be "Lines"
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

        Get-CoverageData -Path $f -Unit "Commands" | Should -BeNullOrEmpty
    }

    It "returns null for Cobertura with zero lines-valid" {
        $f = "$TestDrive/gcd-zero.xml"
        @"
<?xml version="1.0"?>
<coverage line-rate="0" lines-covered="0" lines-valid="0">
  <packages><package name="p"><classes></classes></package></packages>
</coverage>
"@ | Set-Content $f -Encoding utf8NoBOM

        Get-CoverageData -Path $f -Unit "Lines" | Should -BeNullOrEmpty
    }

    It "returns null for empty XML file (no root element)" {
        $f = "$TestDrive/gcd-empty.xml"
        "" | Set-Content $f -Encoding utf8NoBOM

        Get-CoverageData -Path $f -Unit "Lines" | Should -BeNullOrEmpty
    }

    It "throws for unrecognized XML root element" {
        $f = "$TestDrive/gcd-unknown.xml"
        @"
<?xml version="1.0"?>
<summary foo="bar" />
"@ | Set-Content $f -Encoding utf8NoBOM

        { Get-CoverageData -Path $f -Unit "Lines" } | Should -Throw -ExpectedMessage "*unrecognized*"
    }
}
