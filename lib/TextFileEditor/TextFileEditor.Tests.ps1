using module .\TextFileEditor.psd1

Describe "Import-TextFile" {
    It "imports" {

        $data = "Testing`n1 2 `r`n3"
        $expected = $data  # Verbatim, including weird newlines.

        $tempFile = "$TestDrive\test_Import-TextFile" + ".tmp"
        $data | Out-File -Encoding ASCII $tempFile

        $result = Import-TextFile $tempFile
        $result | Should -Be $expected
    }
}

Describe "[LineArray]::new" {
    It "creates" {
        $lineArray = [LineArray]::new("a`nb")

        $lineArray.GetNl() | Should -Be "`n"
        $lineArray.ToString() | Should -Be "a`nb"
    }

    It "recognizes Mac-style newlines" {
        $lineArray = [LineArray]::new("a`rb")

        $lineArray.GetNl() | Should -Be "`r"
        $lineArray.ToString() | Should -Be "a`rb"
    }

    Context "trailingNewline" {
        It "includes an empty string at the end" {
            $lineArray = [LineArray]::new("a`r`n")
            $lineArray.ToString() | Should -Be "a`r`n"
            $lineArray.GetNl() | Should -Be "`r`n"
        }
    }

    Context "emptyString" {
        It "Succeeds" {
            $lineArray = [LineArray]::new("")
            $lineArray.ToString() | Should -Be ""

            $lineArray.GetNl() | Should -Be "`n" # This is the default when detection sees no newlines
        }
    }
}

Describe "GetLineCount" {
    It "counts lines" {
        $lineArray = [LineArray]::new("a`n`nb`nc")
        $lineArray.GetLineCount() | Should -Be 4
    }
    It "handles 1 line, even if it's just a space" {
        $lineArray = [LineArray]::new(" ")
        $lineArray.GetLineCount() | Should -Be 1
    }
    It "handles 0 lines" {
        $lineArray = [LineArray]::new("")
        $lineArray.GetLineCount() | Should -Be 0
    }
}


Describe "[LineArray]::IsEmpty" {
    It "Succeeds" {
        $lineArray = [LineArray]::new("")
        $lineArray.IsEmpty() | Should -BeTrue

        $lineArray = [LineArray]::new("a")
        $lineArray.IsEmpty() | Should -BeFalse

        $lineArray = [LineArray]::new("`n")
        $lineArray.IsEmpty() | Should -BeFalse

        $lineArray = [LineArray]::new(" ")
        $lineArray.IsEmpty() | Should -BeFalse
    }
}

Describe "[LineArray]::ToString" {
    It "returns a string" {
        $lineArray = [LineArray]::new("a`nb")
        $lineArray.ToString() | Should -Be "a`nb"
    }
    Context "trailing newline" {
        It "preserves the trailing newline" {
            $lineArray = [LineArray]::new("a`n")
            $lineArray.ToString() | Should -Be "a`n"
        }
    }
    Context "empty string" {
        It "produces an empty string" {
            $lineArray = [LineArray]::new("")
            $lineArray.ToString() | Should -Be ""
        }
    }
    Context "2 empty strings" {
        It "produces 1 newline" {
            $lineArray = [LineArray]::new("`n")
            $lineArray.ToString() | Should -Be "`n"
        }
    }
}

Describe "Format-ReplaceLines" {
    It "returns a modified multiline string" {
        Format-ReplaceLines "a`nb`nc`nd" @{idxFirst=1; idxLast=2} "e" | Should -Be "a`ne`nd"
    }
    Context "Windows-style newlines" {
        It "remembers and preserves the file's newline format" {
            Format-ReplaceLines "a`r`nb`r`nc`r`nd" @{idxFirst=1; idxLast=2} "e" | Should -Be "a`r`ne`r`nd"
        }
        It "favors the file's newline format over that of the inserted text" {
            Format-ReplaceLines "a`r`nb`r`nc`r`nd" @{idxFirst=1; idxLast=2} "e`nf`ng" | Should -Be "a`r`ne`r`nf`r`ng`r`nd"
        }
    }
}

Describe "Read-Lines" {
    It "returns the given lines" {
        Read-Lines "a`nb`nc`nd`ne`nf" @{idxFirst=1; idxLast=3} | Should -Be "b`nc`nd"
    }
}

Describe "Add-Lines" {
    It "returns a version with the lines added" {
        Add-Lines "a`nb`nc" 1 "d`ne" | Should -Be "a`nd`ne`nb`nc"
    }
}

Describe "[LineArray]::IndentEachLine" {
    It "indents each line with spaces" {
        $la = [LineArray]::new("a`nb")
        $la.IndentEachLine(2)
        $la | Should -Be "  a`n  b"
    }
    It "doesn't notice already-existing indentation" {
        $la = [LineArray]::new(" a")
        $la.IndentEachLine(1)
        $la | Should -Be "  a"
    }
}

Describe "[LineArray]::ReplaceLines" {
    It "replaces lines" {
        $la = [LineArray]::new("a`nb`nC`nD`nE`nf")
        $laNew = [LineArray]::new("X`nY")
        $range = @{ idxFirst = 2; idxLast = 4 }
        $la.ReplaceLines($range, $laNew)
        $la | Should -Be "a`nb`nX`nY`nf"
    }
    It "handles the beginning" {
        $la = [LineArray]::new("C`nD`nE`nf")
        $laNew = [LineArray]::new("X`nY")
        $range = @{ idxFirst = 0; idxLast = 2 }
        $la.ReplaceLines($range, $laNew)
        $la | Should -Be "X`nY`nf"
    }
    It "handles the end" {
        $la = [LineArray]::new("a`nb`nC`nD`nE")
        $laNew = [LineArray]::new("X`nY")
        $range = @{ idxFirst = 2; idxLast = 4 }
        $la.ReplaceLines($range, $laNew)
        $la | Should -Be "a`nb`nX`nY"
    }
    It "supports pure insertion" {
        $la = [LineArray]::new("a`nb`nc`nd`nE")
        $laNew = [LineArray]::new("X`nY")
        $range = @{ idxFirst = 2; idxLast = 1 }
        $la.ReplaceLines($range, $laNew)
        $la | Should -Be "a`nb`nX`nY`nc`nd`nE"
    }
    It "supports pure deletion" {
        $la = [LineArray]::new("a`nb`nC`nD`ne")
        $laNew = [LineArray]::new("")
        $range = @{ idxFirst = 2; idxLast = 3 }
        $la.ReplaceLines($range, $laNew)
        $la | Should -Be "a`nb`ne"
    }
}
