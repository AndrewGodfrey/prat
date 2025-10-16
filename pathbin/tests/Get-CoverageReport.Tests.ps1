BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1

    # shouldMatchRow: Once Pester 6 releases, we can hopefully remove this in favor of "Should-BeEquivalent"
    function shouldMatchRow($actual, $expected) {
        $actual.GetType().Name | Should -Be "PSCustomObject"
        $actual.File | Should -Be $expected.File
        $actual.Methods | Should -Be $expected.Methods
        $actual.Lines | Should -Be $expected.Lines
        $actual.Instructions | Should -Be $expected.Instructions
    }
}

Describe "Get-CoverageReport" {
    It "Creates a repoort" {
        $coverageFile = @"
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
            <report name="Pester (1/1/2025 00:00:00)">
            <sessioninfo id="this" start="1" dump="2" />
            <package name="C:/Users/Alice/prat/pathbin">

                <class name="C:/Users/Alice/prat/pathbin/Add-Utf8Bom" sourcefilename="Add-Utf8Bom.ps1">
                <method name="&lt;script&gt;" desc="()" line="5">
                    <counter type="INSTRUCTION" missed="13" covered="0" />
                    <counter type="LINE" missed="11" covered="0" />
                    <counter type="METHOD" missed="1" covered="0" />
                </method>
                <counter type="INSTRUCTION" missed="13" covered="13" />  <!-- deliberately inconsistent, to verify that this section is ignored (class-level stats) -->
                <counter type="LINE" missed="11" covered="0" />
                <counter type="METHOD" missed="1" covered="0" />
                <counter type="CLASS" missed="1" covered="0" />
                </class>
                <class name="C:/Users/Alice/prat/pathbin/Analyze-FileExtensions" sourcefilename="Analyze-FileExtensions.ps1">
                <method name="&lt;script&gt;" desc="()" line="7">
                    <counter type="INSTRUCTION" missed="0" covered="27" />
                    <counter type="LINE" missed="0" covered="1" />
                    <counter type="METHOD" missed="0" covered="9" />
                </method>
                </class>

                <class name="C:/Users/Alice/prat/pathbin/Write-DebugValue" sourcefilename="Write-DebugValue.ps1">
                <method name="Format-IndentEachLine" desc="()" line="9">
                    <counter type="INSTRUCTION" missed="0" covered="0" /> <!-- testing the 'total = 0' case -->
                    <counter type="LINE" missed="1" covered="6" />
                    <counter type="METHOD" missed="1" covered="0" />
                </method>
                <method name="&lt;script&gt;" desc="()" line="21">
                    <counter type="INSTRUCTION" missed="0" covered="0" />
                    <counter type="LINE" missed="1" covered="12" />
                    <counter type="METHOD" missed="0" covered="9" /> <!-- hacked to give 90% method coverage -->
                </method>
                </class>

                <sourcefile name="Write-DebugValue.ps1"> <!-- this section is ignored (not sure what it is) -->
                <line nr="9" mi="2" ci="0" mb="0" cb="0" />
                <line nr="10" mi="2" ci="0" mb="0" cb="0" />
                <counter type="INSTRUCTION" missed="22" covered="1" />
                <counter type="LINE" missed="17" covered="1" />
                <counter type="METHOD" missed="1" covered="1" />
                <counter type="CLASS" missed="1" covered="0" />
                </sourcefile>

                <counter type="INSTRUCTION" missed="632" covered="90" /> <!-- this section is ignored (package-level stats) -->
                <counter type="LINE" missed="445" covered="67" />
                <counter type="METHOD" missed="62" covered="16" />
                <counter type="CLASS" missed="32" covered="13" />
            </package>
            
            <counter type="INSTRUCTION" missed="638" covered="114" /> <!-- this section is ignored (report-level stats) -->
            <counter type="LINE" missed="449" covered="91" />
            <counter type="METHOD" missed="63" covered="22" />
            <counter type="CLASS" missed="32" covered="17" />
            </report>
"@

        $fn = createTestFile $coverageFile.Trim() ".xml"

        # Act
        $result = Get-CoverageReport $fn -ShowAll -CoverageGoalPercent 70 -Unformatted

        # Assert
        shouldMatchRow $result[0] @{File='Add-Utf8Bom.ps1'; Methods=0; Lines=0; Instructions=0}
        shouldMatchRow $result[1] @{File='Analyze-FileExtensions.ps1'; Methods=100; Lines=100; Instructions=100}
        shouldMatchRow $result[2] @{File='Write-DebugValue.ps1'; Methods=90; Lines=90; Instructions=0}
        shouldMatchRow $result[3] @{Methods=90; Lines=59.375; Instructions=67.5}
        $result[4] | Should -Be 'Files meeting goal: 1'
    }
}
