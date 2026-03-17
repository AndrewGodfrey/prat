BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    function writeLf([string] $path) {
        [System.IO.File]::WriteAllText($path, "line1`nline2`n", [System.Text.UTF8Encoding]::new($false))
    }

    function hasCrlf([string] $path) {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
            if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10) { return $true }
        }
        return $false
    }
}

Describe "On-PostToolUse (main)" -Tag Integration {
    BeforeEach {
        $script:testRoot = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "On-PostToolUse.Tests"
        $script:gitDir   = "$testRoot\git"
        $script:noGitDir = "$testRoot\nogit"
        mkdir $gitDir   | Out-Null
        mkdir $noGitDir | Out-Null

        git init $gitDir 2>$null | Out-Null
        git -C $gitDir config user.email "test@example.com" 2>$null | Out-Null
        git -C $gitDir config user.name  "Test"             2>$null | Out-Null
        # Disable autocrlf by default; individual tests opt in explicitly
        git -C $gitDir config core.autocrlf false 2>$null | Out-Null
    }
    AfterEach {
        Remove-Item $testRoot -Recurse -Force
    }

    It "does nothing when file path is null" {
        { main $null } | Should -Not -Throw
    }

    It "does nothing when file does not exist" {
        { main "$gitDir\nonexistent.txt" } | Should -Not -Throw
    }

    It "does not convert when file is not inside a git repo" {
        $file = "$noGitDir\test.txt"
        writeLf $file

        main $file

        hasCrlf $file | Should -BeFalse
    }

    It "does not convert when repo has no eol rule and autocrlf=false" {
        $file = "$gitDir\test.txt"
        writeLf $file

        main $file

        hasCrlf $file | Should -BeFalse
    }

    It "converts LF to CRLF when .gitattributes specifies eol=crlf" {
        Set-Content "$gitDir\.gitattributes" "* eol=crlf" -Encoding utf8NoBOM
        $file = "$gitDir\test.txt"
        writeLf $file

        main $file

        hasCrlf $file | Should -BeTrue
    }

    It "does not convert when .gitattributes specifies eol=lf" {
        Set-Content "$gitDir\.gitattributes" "* eol=lf" -Encoding utf8NoBOM
        $file = "$gitDir\test.txt"
        writeLf $file

        main $file

        hasCrlf $file | Should -BeFalse
    }

    It "converts when autocrlf=true and safecrlf=true" {
        git -C $gitDir config core.autocrlf true 2>$null | Out-Null
        git -C $gitDir config core.safecrlf true 2>$null | Out-Null
        $file = "$gitDir\test.txt"
        writeLf $file

        main $file

        hasCrlf $file | Should -BeTrue
    }

    It "converts when autocrlf=true and safecrlf=warn" {
        git -C $gitDir config core.autocrlf true 2>$null | Out-Null
        git -C $gitDir config core.safecrlf warn 2>$null | Out-Null
        $file = "$gitDir\test.txt"
        writeLf $file

        main $file

        hasCrlf $file | Should -BeTrue
    }

    It "does not convert when autocrlf=true but safecrlf=false" {
        git -C $gitDir config core.autocrlf true 2>$null | Out-Null
        git -C $gitDir config core.safecrlf false 2>$null | Out-Null
        $file = "$gitDir\test.txt"
        writeLf $file

        main $file

        hasCrlf $file | Should -BeFalse
    }

    It "is idempotent: already-CRLF file is not double-converted" {
        Set-Content "$gitDir\.gitattributes" "* eol=crlf" -Encoding utf8NoBOM
        $file = "$gitDir\test.txt"
        [System.IO.File]::WriteAllText($file, "line1`r`nline2`r`n", [System.Text.UTF8Encoding]::new($false))

        main $file

        $after = [System.IO.File]::ReadAllBytes($file)
        # No \r\r\n sequences
        $doubled = $false
        for ($i = 0; $i -lt $after.Length - 2; $i++) {
            if ($after[$i] -eq 13 -and $after[$i + 1] -eq 13) { $doubled = $true }
        }
        $doubled | Should -BeFalse
    }

    It "skips binary files (null byte present)" {
        Set-Content "$gitDir\.gitattributes" "* eol=crlf" -Encoding utf8NoBOM
        $file = "$gitDir\test.bin"
        [System.IO.File]::WriteAllBytes($file, [byte[]]@(104, 105, 0, 10))

        main $file

        [System.IO.File]::ReadAllBytes($file) | Should -Be @(104, 105, 0, 10)
    }
}
