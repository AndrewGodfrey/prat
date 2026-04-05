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

    It "parses line-level data from sourcefile elements into perFileLineData" {
        $xml = @'
<report name="test">
<package name="C:/repo/pathbin">
  <class name="C:/repo/pathbin/Foo" sourcefilename="Foo.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="1" covered="3" />
      <counter type="LINE" missed="1" covered="2" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
    <method name="Get-Foo" desc="()" line="10">
      <counter type="INSTRUCTION" missed="4" covered="0" />
      <counter type="LINE" missed="2" covered="0" />
      <counter type="METHOD" missed="1" covered="0" />
    </method>
  </class>
  <sourcefile name="Foo.ps1">
    <line nr="1" mi="0" ci="1" mb="0" cb="0" />
    <line nr="3" mi="0" ci="1" mb="0" cb="0" />
    <line nr="5" mi="1" ci="0" mb="0" cb="0" />
    <line nr="10" mi="2" ci="0" mb="0" cb="0" />
    <line nr="11" mi="2" ci="0" mb="0" cb="0" />
  </sourcefile>
</package>
</report>
'@
        $f = "$TestDrive/lines.xml"
        $xml | Set-Content $f

        $result = & $script -CoverageFile $f

        $filePath = (Join-Path "C:/repo/pathbin" "Foo.ps1").Replace('\', '/')
        $lines = $result.perFileLineData[$filePath]
        $lines | Should -HaveCount 5
        $lines[0].nr      | Should -Be 1
        $lines[0].covered | Should -Be $true
        $lines[1].nr      | Should -Be 3
        $lines[1].covered | Should -Be $true
        $lines[2].nr      | Should -Be 5
        $lines[2].covered | Should -Be $false
        $lines[3].nr      | Should -Be 10
        $lines[3].covered | Should -Be $false
    }

    It "throws when RepoRoot is supplied, format is CoverageGutters, and a path is outside RepoRoot" {
        $xml = @'
<report name="test">
<package name="C:/some/other/tree">
  <class name="C:/some/other/tree/Foo" sourcefilename="Foo.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="0" covered="1" />
      <counter type="LINE" missed="0" covered="1" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
</package>
</report>
'@
        $f = "$TestDrive/mismatch.xml"
        $xml | Set-Content $f

        { & $script -CoverageFile $f -RepoRoot "C:/repo" -ValidateRepoRoot } | Should -Throw "*outside RepoRoot*"
    }

    It "does not throw when RepoRoot is supplied, format is CoverageGutters, and all paths are under RepoRoot" {
        $xml = @'
<report name="test">
<package name="C:/repo/pathbin">
  <class name="C:/repo/pathbin/Foo" sourcefilename="Foo.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="0" covered="1" />
      <counter type="LINE" missed="0" covered="1" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
</package>
</report>
'@
        $f = "$TestDrive/valid.xml"
        $xml | Set-Content $f

        { & $script -CoverageFile $f -RepoRoot "C:/repo" -ValidateRepoRoot } | Should -Not -Throw
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

    Context "Cobertura format" {
        BeforeAll {
            # Absolute filenames (dotnet-coverage style: no <sources> element)
            $coberturaXml = @'
<coverage line-rate="0.75" lines-covered="3" lines-valid="4">
  <packages>
    <package name="MyPackage">
      <classes>
        <class filename="C:/repo/src/Foo.cs">
          <methods>
            <method name="Greet" signature="(string)">
              <lines>
                <line number="5" hits="1" />
                <line number="6" hits="0" />
              </lines>
            </method>
            <method name="GreetFormal" signature="(string, string)">
              <lines>
                <line number="10" hits="1" />
                <line number="11" hits="1" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="5"  hits="1" />
            <line number="6"  hits="0" />
            <line number="10" hits="1" />
            <line number="11" hits="1" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $coberturaFile = "$TestDrive/cobertura.xml"
            $coberturaXml | Set-Content $coberturaFile
        }

        It "parses Cobertura format: perFileReport with LINE coverage from hits" {
            $result = & $script -CoverageFile $coberturaFile

            $result.perFileReport.Keys | Should -Contain "C:/repo/src/Foo.cs"
            $result.perFileReport["C:/repo/src/Foo.cs"].LINE.covered | Should -Be 3
            $result.perFileReport["C:/repo/src/Foo.cs"].LINE.missed  | Should -Be 1
        }

        It "uses LINE as proxy for INSTRUCTION" {
            $result = & $script -CoverageFile $coberturaFile

            $result.perFileReport["C:/repo/src/Foo.cs"].INSTRUCTION.covered | Should -Be 3
            $result.perFileReport["C:/repo/src/Foo.cs"].INSTRUCTION.missed  | Should -Be 1
        }

        It "builds per-file method data with name, startLine inferred from first line, and LINE/INSTRUCTION coverage" {
            $result = & $script -CoverageFile $coberturaFile

            $methods = $result.perFileMethodData["C:/repo/src/Foo.cs"]
            $methods | Should -HaveCount 2
            $methods[0].name                | Should -Be "Greet"
            $methods[0].startLine           | Should -Be 5
            $methods[0].startLine           | Should -BeOfType [int]
            $methods[0].LINE.covered        | Should -Be 1
            $methods[0].LINE.missed         | Should -Be 1
            $methods[0].INSTRUCTION.covered | Should -Be 1
            $methods[0].INSTRUCTION.missed  | Should -Be 1
            $methods[1].name                | Should -Be "GreetFormal"
            $methods[1].startLine           | Should -Be 10
            $methods[1].LINE.covered        | Should -Be 2
            $methods[1].LINE.missed         | Should -Be 0
        }

        It "populates perFileLineData from class-level lines" {
            $result = & $script -CoverageFile $coberturaFile

            $lines = $result.perFileLineData["C:/repo/src/Foo.cs"]
            $lines | Should -HaveCount 4
            $lines[0].nr      | Should -Be 5
            $lines[0].covered | Should -Be $true
            $lines[1].nr      | Should -Be 6
            $lines[1].covered | Should -Be $false
            $lines[2].nr      | Should -Be 10
            $lines[2].covered | Should -Be $true
        }

        It "accumulates totals across all methods" {
            $result = & $script -CoverageFile $coberturaFile

            $result.totals.LINE.covered   | Should -Be 3
            $result.totals.LINE.missed    | Should -Be 1
            $result.totals.METHOD.covered | Should -Be 2  # both methods have at least one covered line
            $result.totals.METHOD.missed  | Should -Be 0
        }

        It "derives METHOD coverage: covered if any line hit, missed if all lines missed" {
            $xml = @'
<coverage>
  <packages>
    <package name="MyPackage">
      <classes>
        <class filename="C:/repo/src/Mixed.cs">
          <methods>
            <method name="HitMethod" signature="()">
              <lines>
                <line number="1" hits="1" />
                <line number="2" hits="0" />
              </lines>
            </method>
            <method name="MissedMethod" signature="()">
              <lines>
                <line number="5" hits="0" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="1" hits="1" />
            <line number="2" hits="0" />
            <line number="5" hits="0" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $f = "$TestDrive/cobertura-method-cov.xml"
            $xml | Set-Content $f

            $result = & $script -CoverageFile $f

            $result.perFileReport["C:/repo/src/Mixed.cs"].METHOD.covered | Should -Be 1
            $result.perFileReport["C:/repo/src/Mixed.cs"].METHOD.missed  | Should -Be 1
            $result.totals.METHOD.covered | Should -Be 1
            $result.totals.METHOD.missed  | Should -Be 1
        }

        It "absolutizes workspace-relative filenames using RepoRoot when no source root" {
            $relXml = @'
<coverage>
  <packages>
    <package name="MyPackage">
      <classes>
        <class filename="src/Foo.cs">
          <methods>
            <method name="Greet" signature="(string)">
              <lines>
                <line number="5" hits="1" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="5" hits="1" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $relFile = "$TestDrive/cobertura-rel.xml"
            $relXml | Set-Content $relFile

            $result = & $script -CoverageFile $relFile -RepoRoot "C:/myrepo"

            $result.perFileReport.Keys | Should -Contain "C:/myrepo/src/Foo.cs"
            $result.perFileReport["C:/myrepo/src/Foo.cs"].LINE.covered | Should -Be 1
        }

        It "absolutizes filenames using source root from sources element" {
            $sourceXml = @'
<coverage>
  <sources>
    <source>C:/myrepo</source>
  </sources>
  <packages>
    <package name="MyPackage">
      <classes>
        <class filename="src/Bar.cs">
          <methods>
            <method name="Run" signature="()">
              <lines>
                <line number="3" hits="0" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="3" hits="0" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $sourceFile = "$TestDrive/cobertura-source.xml"
            $sourceXml | Set-Content $sourceFile

            $result = & $script -CoverageFile $sourceFile

            $result.perFileReport.Keys | Should -Contain "C:/myrepo/src/Bar.cs"
            $result.perFileReport["C:/myrepo/src/Bar.cs"].LINE.missed | Should -Be 1
        }

        It "ignores source element when it is '.'" {
            $dotSourceXml = @'
<coverage>
  <sources>
    <source>.</source>
  </sources>
  <packages>
    <package name="MyPackage">
      <classes>
        <class filename="C:/repo/src/Baz.cs">
          <methods>
            <method name="Run" signature="()">
              <lines>
                <line number="1" hits="1" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="1" hits="1" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $dotSourceFile = "$TestDrive/cobertura-dot-source.xml"
            $dotSourceXml | Set-Content $dotSourceFile

            $result = & $script -CoverageFile $dotSourceFile

            # absolute filename preserved as-is (source "." is ignored)
            $result.perFileReport.Keys | Should -Contain "C:/repo/src/Baz.cs"
        }

        It "absolute filename takes priority over source root" {
            $xml = @'
<coverage>
  <sources>
    <source>C:/myrepo</source>
  </sources>
  <packages>
    <package name="MyPackage">
      <classes>
        <class filename="C:/other/place/Abs.cs">
          <methods>
            <method name="Run" signature="()">
              <lines>
                <line number="1" hits="1" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="1" hits="1" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $f = "$TestDrive/cobertura-abs-priority.xml"
            $xml | Set-Content $f

            $result = & $script -CoverageFile $f

            # absolute filename wins; source root not prepended
            $result.perFileReport.Keys | Should -Contain "C:/other/place/Abs.cs"
            $result.perFileReport.Keys | Should -Not -Contain "C:/myrepo/C:/other/place/Abs.cs"
        }

        It "handles method with missing lines element without phantom missed entries" {
            $xml = @'
<coverage>
  <packages>
    <package name="MyPackage">
      <classes>
        <class filename="C:/repo/Empty.cs">
          <methods>
            <method name="Abstract" signature="()">
              <lines></lines>
            </method>
          </methods>
          <lines></lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $f = "$TestDrive/cobertura-empty-lines.xml"
            $xml | Set-Content $f

            $result = & $script -CoverageFile $f

            $result.totals.LINE.covered | Should -Be 0
            $result.totals.LINE.missed  | Should -Be 0
            $result.perFileLineData["C:/repo/Empty.cs"] | Should -HaveCount 0
        }

        It "accumulates classes from multiple packages" {
            $xml = @'
<coverage>
  <packages>
    <package name="PkgA">
      <classes>
        <class filename="C:/repo/A.cs">
          <methods>
            <method name="Run" signature="()">
              <lines>
                <line number="1" hits="1" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="1" hits="1" />
          </lines>
        </class>
      </classes>
    </package>
    <package name="PkgB">
      <classes>
        <class filename="C:/repo/B.cs">
          <methods>
            <method name="Run" signature="()">
              <lines>
                <line number="5" hits="0" />
              </lines>
            </method>
          </methods>
          <lines>
            <line number="5" hits="0" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
            $f = "$TestDrive/cobertura-multi-pkg.xml"
            $xml | Set-Content $f

            $result = & $script -CoverageFile $f

            $result.perFileReport.Keys | Should -Contain "C:/repo/A.cs"
            $result.perFileReport.Keys | Should -Contain "C:/repo/B.cs"
            $result.totals.LINE.covered | Should -Be 1
            $result.totals.LINE.missed  | Should -Be 1
        }
    }
}
