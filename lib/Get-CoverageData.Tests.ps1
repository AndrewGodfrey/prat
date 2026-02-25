BeforeAll {
    $script = "$PSScriptRoot/Get-CoverageData.ps1"
}

Describe "Get-CoverageData" {
    It "parses CoverageGutters format into per-file report with absolute paths" {
        $xml = @'
<report name="test">
<package name="C:/repo/pathbin">
  <class name="C:/repo/pathbin/Foo" sourcefilename="Foo.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="5" covered="10" />
      <counter type="LINE" missed="2" covered="8" />
      <counter type="METHOD" missed="1" covered="1" />
    </method>
  </class>
</package>
</report>
'@
        $f = "$TestDrive/cg.xml"
        $xml | Set-Content $f

        $result = & $script -CoverageFile $f

        $filePath = (Join-Path "C:/repo/pathbin" "Foo.ps1").Replace('\', '/')
        $result.perFileReport.Keys | Should -Contain $filePath
        $result.perFileReport[$filePath].INSTRUCTION.covered | Should -Be 10
        $result.perFileReport[$filePath].INSTRUCTION.missed  | Should -Be 5
        $result.perFileReport[$filePath].METHOD.missed  | Should -Be 1
        $result.perFileReport[$filePath].LINE.missed  | Should -Be 2
    }

    It "parses JaCoCo format: resolves sourcefilename relative to RepoRoot" {
        $xml = @'
<report name="test">
<package name="prat/lib">
  <class name="prat/lib/Foo" sourcefilename="lib/Foo.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="3" covered="7" />
      <counter type="LINE" missed="1" covered="5" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
</package>
</report>
'@
        $f = "$TestDrive/jacoco.xml"
        $xml | Set-Content $f
        $repoRoot = "C:/Users/andrew/prat"

        $result = & $script -CoverageFile $f -RepoRoot $repoRoot

        $filePath = (Join-Path $repoRoot "lib/Foo.ps1").Replace('\', '/')
        $result.perFileReport.Keys | Should -Contain $filePath
        $result.perFileReport[$filePath].INSTRUCTION.covered | Should -Be 7
        $result.perFileReport[$filePath].INSTRUCTION.missed  | Should -Be 3
        $result.perFileReport[$filePath].LINE.missed  | Should -Be 1
    }

    It "builds per-file method data: name, start line, and instruction coverage" {
        $xml = @'
<report name="test">
<package name="C:/repo/pathbin">
  <class name="C:/repo/pathbin/Bar" sourcefilename="Bar.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="2" covered="8" />
      <counter type="LINE" missed="1" covered="4" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
    <method name="My-Function" desc="()" line="10">
      <counter type="INSTRUCTION" missed="5" covered="0" />
      <counter type="LINE" missed="3" covered="90" />
      <counter type="METHOD" missed="1" covered="0" />
    </method>
  </class>
</package>
</report>
'@
        $f = "$TestDrive/methods.xml"
        $xml | Set-Content $f

        $result = & $script -CoverageFile $f

        $filePath = (Join-Path "C:/repo/pathbin" "Bar.ps1").Replace('\', '/')
        $methods = $result.perFileMethodData[$filePath]
        $methods | Should -HaveCount 2
        $methods[0].name                    | Should -Be "<script>"
        $methods[0].startLine               | Should -Be 1
        $methods[0].INSTRUCTION.covered     | Should -Be 8
        $methods[0].INSTRUCTION.missed      | Should -Be 2
        $methods[1].name                    | Should -Be "My-Function"
        $methods[1].startLine               | Should -Be 10
        $methods[1].INSTRUCTION.missed      | Should -Be 5
        $methods[1].LINE.covered            | Should -Be 90
    }

    It "treats PSDrive paths (e.g. TestDrive:\) as CoverageGutters format" {
        $xml = @'
<report name="test">
<package name="TestDrive:\">
  <class name="TestDrive:\Foo" sourcefilename="Foo.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="1" covered="2" />
      <counter type="LINE" missed="0" covered="1" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
</package>
</report>
'@
        $f = "$TestDrive/psdrive.xml"
        $xml | Set-Content $f

        $result = & $script -CoverageFile $f

        $filePath = (Join-Path "TestDrive:\" "Foo.ps1").Replace('\', '/')
        $result.perFileReport.Keys | Should -Contain $filePath
        $result.perFileReport[$filePath].INSTRUCTION.covered | Should -Be 2
    }

    It "accumulates totals across all methods and files" {
        $xml = @'
<report name="test">
<package name="C:/repo">
  <class name="C:/repo/A" sourcefilename="A.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="3" covered="7" />
      <counter type="LINE" missed="1" covered="9" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
  <class name="C:/repo/B" sourcefilename="B.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="1" covered="3" />
      <counter type="LINE" missed="0" covered="2" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
    <method name="My-Function" desc="()" line="10">
      <counter type="INSTRUCTION" missed="5" covered="10" />
      <counter type="LINE" missed="3" covered="90" />
      <counter type="METHOD" missed="1" covered="0" />
    </method>
  </class>
</package>
</report>
'@
        $f = "$TestDrive/totals.xml"
        $xml | Set-Content $f

        $result = & $script -CoverageFile $f

        $result.totals.INSTRUCTION.covered | Should -Be 20
        $result.totals.INSTRUCTION.missed  | Should -Be 9
    }
}
