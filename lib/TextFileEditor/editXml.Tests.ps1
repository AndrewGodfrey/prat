using module .\TextFileEditor.psd1

Describe "Find-XmlSection" {
    BeforeEach {
        $filename = "text.xml"
    }
    It "finds the section" {
        $data = @"
            <root>
                <section>
                    <item>foo</item>
                </section>
            </root>
"@
        $pathArray = @("root", "section")
        $result = Find-XmlSection $data $pathArray $filename 
        $result.idxFirst | Should -Be 1
        $result.idxLast | Should -Be 3
    }

    It "finds the root" {
        # In this case, $xmlReader.NodeType is "None" after we Skip(), because we're at the end of the XML.
        $data = @"
            <root>
                <section>
                    <item>foo</item>
                </section>
            </root>
"@
        $pathArray = @("root")
        $result = Find-XmlSection $data $pathArray $filename 
        $result.idxFirst | Should -Be 0
        $result.idxLast | Should -Be 4
    }

    It "finds a section with a given attribute" {
        $data = @"
            <root>
                <section name="s1">
                    <item>foo</item>
                </section>
                <blug/>
                <section name="s2">
                    <item>bar</item>
                </section>
            </root>
"@
        $pathArray = @("root", "section[@name='s2']")
        $result = Find-XmlSection $data $pathArray $filename 
        $result.idxFirst | Should -Be 5
        $result.idxLast | Should -Be 7
    }

    It "returns null if no matches" {
        $data = @"
            <root>
                <section>
                    <item>foo</item>
                </section>
            </root>
"@
        $pathArray = @("root", "blug")
        $result = Find-XmlSection $data $pathArray $filename 
        $result | Should -BeNull
    }    

    It "throws if multiple matches" {
        $data = @"
            <root>
                <section>
                    <item>foo</item>
                </section>
                <section>
                    <item>bar</item>
                </section>
            </root>
"@
        $pathArray = @("root", "section")
        {Find-XmlSection $data $pathArray $filename} | Should -Throw -ExpectedMessage "Too many matches for '//root/section' in 'text.xml'"
    }

    It "throws if start node not on its own line" {
        $data = @"
            <root>
                <section><item>
                    foo
                    </item>
                </section>
            </root>
"@
        $pathArray = @("root", "section", "item")
        # Line numbers in error messages are 1-based, while idxFirst and idxLast are 0-based.
        {Find-XmlSection $data $pathArray $filename} | Should -Throw -ExpectedMessage "Error: Start node isn't on its own line (text.xml : 2)"
    }

    It "throws if end node not on its own line" {
        $data = @"
            <root>
                <section>
                    <item>
                    foo
                    </item>
                </section> </root>
"@
        $pathArray = @("root", "section")
        {Find-XmlSection $data $pathArray $filename} | Should -Throw -ExpectedMessage "Error: End node isn't on its own line (text.xml : 6)"
    }
}

Describe "Update-XmlSection" {
    BeforeEach {
        $filename = "text.xml"
        $inputXml = @"
            <xml>
                <root>
                    <section name="s1">
                        <item>foo</item>
                    </section>
                    <blug></blug>
                    <section name="s2">
                        <item>bar</item>
                    </section>
                </root>
            </xml>
"@
    }
    It "updates the section if found" {
        $pathArray = @("root", "section[@name='s2']")
        $newSection = @"
                    <section name="s2">
                        <item>baz</item>
                    </section>
"@
        $result = Update-XmlSection $inputXml $pathArray $newSection $filename 
        $result | Should -Be @"
            <xml>
                <root>
                    <section name="s1">
                        <item>foo</item>
                    </section>
                    <blug></blug>
                    <section name="s2">
                        <item>baz</item>
                    </section>
                </root>
            </xml>
"@
    }
    It "adds a new section if match not found" {
        $pathArray = @("root", "section[@name='s3']")
        $newSection = @"
                    <section name="s3">
                        <item>baz</item>
                    </section>
"@
        $result = Update-XmlSection $inputXml $pathArray $newSection $filename 
        $result | Should -Be @"
            <xml>
                <root>
                    <section name="s1">
                        <item>foo</item>
                    </section>
                    <blug></blug>
                    <section name="s2">
                        <item>bar</item>
                    </section>
                    <section name="s3">
                        <item>baz</item>
                    </section>
                </root>
            </xml>
"@
    }
    It "throws if parent section not found" {
        $pathArray = @("groot", "section[@name='s3']")
        $newSection = "whatever"
        {Update-XmlSection $inputXml $pathArray $newSection $filename} | Should -Throw -ExpectedMessage "Can't find 'groot' section in 'text.xml'"
    }
}
