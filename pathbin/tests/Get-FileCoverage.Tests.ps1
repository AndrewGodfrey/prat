BeforeAll {
    $script = "$PSScriptRoot/../Get-FileCoverage.ps1"
}

Describe "Get-FileCoverage" {
    BeforeAll {
        $coverageXml = @'
<report name="test">
<package name="C:/repo/pathbin">
  <class name="C:/repo/pathbin/Foo" sourcefilename="Foo.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="0" covered="10" />
      <counter type="LINE" missed="0" covered="5" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
    <method name="Get-Something" desc="()" line="20">
      <counter type="INSTRUCTION" missed="8" covered="2" />
      <counter type="LINE" missed="4" covered="1" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
    <method name="Set-Something" desc="()" line="35">
      <counter type="INSTRUCTION" missed="6" covered="0" />
      <counter type="LINE" missed="3" covered="0" />
      <counter type="METHOD" missed="1" covered="0" />
    </method>
  </class>
</package>
</report>
'@
        $coverageFile = "$TestDrive/coverage.xml"
        $coverageXml | Set-Content $coverageFile
    }

    It "returns one row per function with name, line, and instruction coverage" {
        $result = & $script -FilePath "C:/repo/pathbin/Foo.ps1" -CoverageFile $coverageFile

        $result | Should -HaveCount 3
        $result[0].Function    | Should -Be "<script>"
        $result[0].Line        | Should -Be 1
        $result[0].Covered     | Should -Be 10
        $result[0].Missed      | Should -Be 0
        $result[1].Function    | Should -Be "Get-Something"
        $result[1].Line        | Should -Be 20
        $result[1].Covered     | Should -Be 2
        $result[1].Missed      | Should -Be 8
        $result[2].Function    | Should -Be "Set-Something"
        $result[2].Missed      | Should -Be 6
    }

    It "returns empty when file is not in coverage data" {
        $result = & $script -FilePath "C:/repo/pathbin/NotInReport.ps1" -CoverageFile $coverageFile

        $result | Should -HaveCount 0
    }

    It "accepts a relative file path by resolving against current directory" {
        "content" | Set-Content "$TestDrive/RelFile.ps1"
        $xml = @"
<report name="test">
<package name="$TestDrive">
  <class name="$TestDrive/RelFile" sourcefilename="RelFile.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="1" covered="9" />
      <counter type="LINE" missed="0" covered="1" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
</package>
</report>
"@
        $xml | Set-Content "$TestDrive/rel-coverage.xml"

        Push-Location $TestDrive
        try {
            $result = & $script -FilePath "RelFile.ps1" -CoverageFile "$TestDrive/rel-coverage.xml"
        } finally {
            Pop-Location
        }

        $result | Should -HaveCount 1
        $result[0].Covered | Should -Be 9
    }
}
