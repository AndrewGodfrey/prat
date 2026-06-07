BeforeAll {
    . $PSScriptRoot/../Set-ClipboardHtml.ps1 -Html '<dummy/>'
}

Describe "Get-HtmlPlainText" {
    It "Returns empty string for empty input" {
        Get-HtmlPlainText '' | Should -Be ''
    }

    It "Strips simple tags" {
        Get-HtmlPlainText '<b>hello</b>' | Should -Be 'hello'
    }

    It "Replaces tags with spaces and normalizes whitespace" {
        Get-HtmlPlainText '<p>a</p><p>b</p>' | Should -Be 'a b'
    }

    It "Decodes named HTML entities" {
        Get-HtmlPlainText 'x &amp; y' | Should -Be 'x & y'
    }

    It "Decodes numeric decimal HTML entities" {
        Get-HtmlPlainText '&#9989; Completed' | Should -Be ([char]9989 + ' Completed')
    }

    It "Decodes numeric hex HTML entities" {
        Get-HtmlPlainText '&#x2705;' | Should -Be ([char]0x2705).ToString()
    }

    It "Trims leading and trailing whitespace" {
        Get-HtmlPlainText '   hello world   ' | Should -Be 'hello world'
    }

    It "Handles realistic table cell content" {
        Get-HtmlPlainText '<td>&#9989; Completed</td>' | Should -Be ([char]9989 + ' Completed')
    }
}
