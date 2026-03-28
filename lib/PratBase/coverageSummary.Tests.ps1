BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-CoverageSummary" {
    BeforeAll {
        Mock Get-CoveragePercentTarget -ModuleName PratBase { return 70 }
    }

    It "returns null for null path" {
        Get-CoverageSummary -Path $null -Unit "Commands" | Should -BeNullOrEmpty
    }

    It "returns null for non-existent file" {
        Get-CoverageSummary -Path "$TestDrive/nonexistent.xml" -Unit "Commands" | Should -BeNullOrEmpty
    }

    It "parses JaCoCo format (report root)" {
        $f = "$TestDrive/jacoco.xml"
        @"
<?xml version="1.0"?>
<report name="test">
  <counter type="INSTRUCTION" missed="50" covered="150" />
  <counter type="CLASS" missed="2" covered="8" />
</report>
"@ | Set-Content $f -Encoding utf8NoBOM

        Get-CoverageSummary -Path $f -Unit "Commands" |
            Should -Be "Covered 75% / 70%. 150/200 Commands in 10 Files."
    }

    It "parses Cobertura format (coverage root)" {
        $f = "$TestDrive/cobertura.xml"
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

        Get-CoverageSummary -Path $f -Unit "Lines" |
            Should -Be "Covered 85% / 70%. 85/100 Lines in 3 Files."
    }

    It "returns null for Cobertura with zero lines-valid" {
        $f = "$TestDrive/cobertura-zero.xml"
        @"
<?xml version="1.0"?>
<coverage line-rate="0" lines-covered="0" lines-valid="0">
  <packages><package name="p"><classes></classes></package></packages>
</coverage>
"@ | Set-Content $f -Encoding utf8NoBOM

        Get-CoverageSummary -Path $f -Unit "Lines" | Should -BeNullOrEmpty
    }

    It "throws for unrecognized XML root element" {
        $f = "$TestDrive/unknown.xml"
        @"
<?xml version="1.0"?>
<summary foo="bar" />
"@ | Set-Content $f -Encoding utf8NoBOM

        { Get-CoverageSummary -Path $f -Unit "Lines" } | Should -Throw -ExpectedMessage "*unrecognized*"
    }
}
