Describe "Format-NumberAsHex" {
    It "Converts a number" {
        Format-NumberAsHex 255 | Should -Be "0xff"
    }
}
