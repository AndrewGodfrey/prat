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

    Context "-Detail" {
        BeforeAll {
            $detailXml = @'
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
            $detailFile = "$TestDrive/detail-coverage.xml"
            $detailXml | Set-Content $detailFile
        }

        It "returns one row per covered/missed range per function" {
            $result = & $script -FilePath "C:/repo/pathbin/Foo.ps1" -CoverageFile $detailFile -Detail

            $result | Should -HaveCount 3
            $result[0].Function  | Should -Be "<script>"
            $result[0].StartLine | Should -Be 1
            $result[0].EndLine   | Should -Be 3
            $result[0].Status    | Should -Be "covered"
            $result[1].Function  | Should -Be "<script>"
            $result[1].StartLine | Should -Be 5
            $result[1].EndLine   | Should -Be 5
            $result[1].Status    | Should -Be "missed"
            $result[2].Function  | Should -Be "Get-Foo"
            $result[2].StartLine | Should -Be 10
            $result[2].EndLine   | Should -Be 11
            $result[2].Status    | Should -Be "missed"
        }

        It "with -Function filters to that function only" {
            $result = & $script -FilePath "C:/repo/pathbin/Foo.ps1" -CoverageFile $detailFile -Detail -Function "Get-Foo"

            $result | Should -HaveCount 1
            $result[0].Function  | Should -Be "Get-Foo"
            $result[0].StartLine | Should -Be 10
            $result[0].EndLine   | Should -Be 11
            $result[0].Status    | Should -Be "missed"
        }
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

    Context "default CoverageFile inference" {
        BeforeAll {
            # git init requires a real path, not a PSDrive path
            $realTestDrive = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
            $repoDir = "$realTestDrive/inferrepo"
            New-Item -ItemType Directory -Path $repoDir | Out-Null
            git init $repoDir --quiet | Out-Null

            $srcDir = "$repoDir/src"
            New-Item -ItemType Directory -Path $srcDir | Out-Null
            "content" | Set-Content "$srcDir/Bar.ps1"

            $coverageDir = "$repoDir/auto/testRuns/last"
            New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null
            @"
<report name="test">
<package name="$srcDir">
  <class name="$srcDir/Bar" sourcefilename="Bar.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="0" covered="7" />
      <counter type="LINE" missed="0" covered="3" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
</package>
</report>
"@ | Set-Content "$coverageDir/coverage.xml"
        }

        It "infers coverage file from FilePath's git repo root when CoverageFile is not supplied" {
            $result = & $script -FilePath "$repoDir/src/Bar.ps1"

            $result | Should -HaveCount 1
            $result[0].Covered | Should -Be 7
        }

        It "uses project subdirectory when -Project is specified" {
            $projectCoverageDir = "$repoDir/auto/testRuns/myproject/last"
            New-Item -ItemType Directory -Path $projectCoverageDir -Force | Out-Null
            @"
<report name="test">
<package name="$srcDir">
  <class name="$srcDir/Bar" sourcefilename="Bar.ps1">
    <method name="&lt;script&gt;" desc="()" line="1">
      <counter type="INSTRUCTION" missed="2" covered="5" />
      <counter type="LINE" missed="0" covered="3" />
      <counter type="METHOD" missed="0" covered="1" />
    </method>
  </class>
</package>
</report>
"@ | Set-Content "$projectCoverageDir/coverage.xml"

            $result = & $script -FilePath "$repoDir/src/Bar.ps1" -Project "myproject"

            $result | Should -HaveCount 1
            $result[0].Covered | Should -Be 5  # 5 from project file, not 7 from default
        }

        It "throws when FilePath is not in a git repo" {
            { & $script -FilePath "/no-git-repo-here/SomeFile.ps1" } | Should -Throw "*not in a git repo*"
        }
    }
}
