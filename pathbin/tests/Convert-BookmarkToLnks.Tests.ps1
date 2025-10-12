BeforeAll {
    $scriptToTest = Resolve-Path "$PSScriptRoot\..\Convert-BookmarkToLnks.ps1"
}

Describe "Convert-BookmarkToLnks.ps1" {
    It "Converts a link from a Firefox bookmark" {
        function Get-HtmlFromClipboard {}
        Mock Get-HtmlFromClipboard { 
            'Version:0.9', 'StartHTML:00000166', 'EndHTML:00000327', 'StartFragment:00000200', 'EndFragment:00000291', 'SourceURL:https://calteches.library.caltech.edu/51/2/CargoCult.htm',
            '<html><body>'
            '<!--StartFragment--><A HREF="https://calteches.library.caltech.edu/51/2/CargoCult.htm">Cargo Cult Science</A>'
            '<!--EndFragment-->', '</body>', '</html>'
        }
        $setToClipboard = $null
        $ref_setToClipboard = [ref] $setToClipboard
        Mock Set-Clipboard { $ref_setToClipboard.Value = $Value }

        $output = &$scriptToTest 6>&1

        $output | Should -Be "Success"
        $setToClipboard | Should -Be "`t[Cargo Cult Science](https://calteches.library.caltech.edu/51/2/CargoCult.htm)`r`n"
    }
}
