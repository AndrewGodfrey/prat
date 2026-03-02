BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    # Import-TextFile is used by Install-TextToFile
    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"

    # Mock for InstallationStage
    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-TextToFile" {
    BeforeEach {
        $testDir = "TestDrive:\instFilesAndFolders.Tests"
        mkdir $testDir | Out-Null
        $testFile = "$testDir\test.txt"
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Creates a new file with SetReadOnly" {
        Install-TextToFile $stage $testFile "hello" -SetReadOnly

        Import-TextFile $testFile | Should -Be "hello"
        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 1
    }

    It "Is idempotent when content and read-only flag match" {
        "hello" | Out-File -Encoding ASCII $testFile
        Set-ItemProperty $testFile -Name IsReadOnly -Value $true

        Install-TextToFile $stage $testFile "hello" -SetReadOnly

        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 0
    }

    It "Updates content on a read-only file" {
        "old content" | Out-File -Encoding ASCII $testFile
        Set-ItemProperty $testFile -Name IsReadOnly -Value $true

        Install-TextToFile $stage $testFile "new content" -SetReadOnly

        Import-TextFile $testFile | Should -Be "new content"
        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 1
    }

    It "Sets read-only when content matches but flag is missing" {
        "hello" | Out-File -Encoding ASCII $testFile

        Install-TextToFile $stage $testFile "hello" -SetReadOnly

        (Get-ItemProperty $testFile).IsReadOnly | Should -BeTrue
        $stage.changeCount | Should -Be 1
    }

    It "Leaves file writable without SetReadOnly" {
        Install-TextToFile $stage $testFile "hello"

        Import-TextFile $testFile | Should -Be "hello"
        (Get-ItemProperty $testFile).IsReadOnly | Should -BeFalse
    }

    It "Is idempotent when newText has CRLF but existing file content matches" {
        "line1`r`nline2`r`nline3" | Out-File -Encoding utf8NoBOM $testFile

        Install-TextToFile $stage $testFile "line1`r`nline2`r`nline3"

        $stage.changeCount | Should -Be 0
    }

    It "Is idempotent when existing file has CRLF but newText has LF" {
        "line1`r`nline2`r`nline3" | Out-File -Encoding utf8NoBOM $testFile

        Install-TextToFile $stage $testFile "line1`nline2`nline3"

        $stage.changeCount | Should -Be 0
    }

    It "Still detects actual content difference when both sides have CRLF" {
        "old`ncontent" | Out-File -Encoding utf8NoBOM $testFile

        Install-TextToFile $stage $testFile "new`r`ncontent"

        $stage.changeCount | Should -Be 1
        Import-TextFile $testFile | Should -Be "new`ncontent"
    }
}

Describe "Install-SetOfFiles" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "SetOfFiles.Tests"
        mkdir $testDir | Out-Null
        $script:srcDir  = "$testDir\src"
        $script:destDir = "$testDir\dest"
        mkdir $srcDir  | Out-Null
        mkdir $destDir | Out-Null  # pre-create so Install-Folder skips the mkdir+ACL path
        $script:stage = [MockStage]::new()
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Prepends header to deployed file content" {
        "file content" | Out-File "$srcDir\SKILL.md" -Encoding utf8NoBOM

        Install-SetOfFiles $stage $srcDir $destDir -Header "<!-- header -->"

        Get-Content "$destDir\SKILL.md" -Raw | Should -BeLike "<!-- header -->*file content*"
    }

    It "Is idempotent when called again with same source and header" {
        "file content" | Out-File "$srcDir\SKILL.md" -Encoding utf8NoBOM
        Install-SetOfFiles $stage $srcDir $destDir -Header "<!-- header -->"
        $firstCount = $stage.changeCount

        Install-SetOfFiles $stage $srcDir $destDir -Header "<!-- header -->"

        $stage.changeCount | Should -Be $firstCount
    }

    It "Sets file read-only when -Header and -SetReadOnly" {
        "file content" | Out-File "$srcDir\SKILL.md" -Encoding utf8NoBOM

        Install-SetOfFiles $stage $srcDir $destDir -Header "<!-- header -->" -SetReadOnly

        (Get-ItemProperty "$destDir\SKILL.md").IsReadOnly | Should -BeTrue
    }
}

Describe "Install-DirectoryJunction" {
    BeforeEach {
        # Junctions require absolute filesystem paths, not PSDrive paths
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "directoryJunction.Tests"
        mkdir $testDir | Out-Null
        $script:stage = [MockStage]::new()
        $script:targetDir = "$testDir\target"
        $script:linkDir = "$testDir\link"
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Creates junction and target directory when neither exists" {
        Install-DirectoryJunction $stage $targetDir $linkDir

        (Get-Item $linkDir).LinkType | Should -Be "Junction"
        (Get-Item $linkDir).Target | Should -Be $targetDir
        Test-Path $targetDir -PathType Container | Should -BeTrue
        $stage.changeCount | Should -BeGreaterThan 0
    }

    It "Is idempotent when junction already points to correct target" {
        mkdir $targetDir | Out-Null
        New-Item -ItemType Junction -Path $linkDir -Target $targetDir | Out-Null

        Install-DirectoryJunction $stage $targetDir $linkDir

        (Get-Item $linkDir).LinkType | Should -Be "Junction"
        (Get-Item $linkDir).Target | Should -Be $targetDir
        $stage.changeCount | Should -Be 0
    }

    It "Throws when link path is an existing directory without -MigrateExisting" {
        mkdir $linkDir | Out-Null
        "file content" | Out-File "$linkDir\existing.txt"

        { Install-DirectoryJunction $stage $targetDir $linkDir } | Should -Throw "*MigrateExisting*"
    }

    It "Moves contents from existing directory to target with -MigrateExisting" {
        mkdir $linkDir | Out-Null
        "file content" | Out-File "$linkDir\existing.txt"
        mkdir "$linkDir\subdir" | Out-Null
        "nested" | Out-File "$linkDir\subdir\nested.txt"

        Install-DirectoryJunction $stage $targetDir $linkDir -MigrateExisting

        (Get-Item $linkDir).LinkType | Should -Be "Junction"
        Test-Path "$targetDir\existing.txt" | Should -BeTrue
        Get-Content "$targetDir\existing.txt" | Should -BeLike "*file content*"
        Test-Path "$targetDir\subdir\nested.txt" | Should -BeTrue
        $stage.changeCount | Should -BeGreaterThan 0
    }

    It "Replaces junction pointing to wrong target, leaving old target data intact" {
        $wrongTarget = "$testDir\wrong"
        mkdir $targetDir | Out-Null
        mkdir $wrongTarget | Out-Null
        "old data" | Out-File "$wrongTarget\old.txt"
        New-Item -ItemType Junction -Path $linkDir -Target $wrongTarget | Out-Null

        Install-DirectoryJunction $stage $targetDir $linkDir

        (Get-Item $linkDir).LinkType | Should -Be "Junction"
        (Get-Item $linkDir).Target | Should -Contain $targetDir
        # Old target and its data should be untouched
        Get-Content "$wrongTarget\old.txt" | Should -BeLike "*old data*"
        $stage.changeCount | Should -BeGreaterThan 0
    }

    It "Throws when link path is an existing file" {
        "not a directory" | Out-File $linkDir

        { Install-DirectoryJunction $stage $targetDir $linkDir } | Should -Throw "*found file*"
    }

    It "Throws when target path is an existing file" {
        "not a directory" | Out-File $targetDir

        { Install-DirectoryJunction $stage $targetDir $linkDir } | Should -Throw "*found a file*"
    }

    It "Creates parent directory of link path if needed" {
        $nestedLink = "$testDir\parent\child\link"

        Install-DirectoryJunction $stage $targetDir $nestedLink

        (Get-Item $nestedLink).LinkType | Should -Be "Junction"
        Test-Path "$testDir\parent\child" -PathType Container | Should -BeTrue
    }

    It "Data is accessible through the junction" {
        mkdir $targetDir | Out-Null
        "hello" | Out-File "$targetDir\data.txt"

        Install-DirectoryJunction $stage $targetDir $linkDir

        Get-Content "$linkDir\data.txt" | Should -BeLike "*hello*"
    }
}

Describe "Merge-DirectoryInto" {
    BeforeEach {
        # fc.exe requires real filesystem paths, not PSDrive paths
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "mergeDir.Tests"
        mkdir $testDir | Out-Null
        $script:srcDir = "$testDir\src"
        $script:destDir = "$testDir\dest"
        mkdir $srcDir | Out-Null
        mkdir $destDir | Out-Null
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    It "Moves files that only exist in source" {
        "source only" | Out-File "$srcDir\a.txt"

        Merge-DirectoryInto $srcDir $destDir

        Get-Content "$destDir\a.txt" | Should -BeLike "*source only*"
        Test-Path "$srcDir\a.txt" | Should -BeFalse
    }

    It "Silently removes source file when contents are identical" {
        "same content" | Out-File -Encoding ASCII "$destDir\a.txt"
        "same content" | Out-File -Encoding ASCII "$srcDir\a.txt"

        $warnings = Merge-DirectoryInto $srcDir $destDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        Get-Content "$destDir\a.txt" | Should -BeLike "*same content*"
        Test-Path "$destDir\a.txt.local-conflict" | Should -BeFalse
        Test-Path "$srcDir\a.txt" | Should -BeFalse
        $warnings | Should -BeNullOrEmpty
    }

    It "Keeps dest version and saves source as .local-conflict" {
        "dest version" | Out-File "$destDir\a.txt"
        "source version" | Out-File "$srcDir\a.txt"

        Merge-DirectoryInto $srcDir $destDir 3>&1 | Out-Null

        Get-Content "$destDir\a.txt" | Should -BeLike "*dest version*"
        Get-Content "$destDir\a.txt.local-conflict" | Should -BeLike "*source version*"
        Test-Path "$srcDir\a.txt" | Should -BeFalse
    }

    It "Emits a warning on conflict" {
        "dest" | Out-File "$destDir\a.txt"
        "source" | Out-File "$srcDir\a.txt"

        $warnings = Merge-DirectoryInto $srcDir $destDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        ($warnings | Where-Object { $_.Message -match "a.txt" }) | Should -Not -BeNullOrEmpty
    }

    It "Throws when source directory conflicts with dest file" {
        "a file" | Out-File "$destDir\name"
        mkdir "$srcDir\name" | Out-Null
        "content" | Out-File "$srcDir\name\child.txt"

        { Merge-DirectoryInto $srcDir $destDir } | Should -Throw "*a file exists*"

        # Nothing should have been mutated
        Test-Path "$srcDir\name\child.txt" | Should -BeTrue
        Get-Content "$destDir\name" | Should -BeLike "*a file*"
    }

    It "Throws when source file conflicts with dest directory" {
        mkdir "$destDir\name" | Out-Null
        "a file" | Out-File "$srcDir\name"

        { Merge-DirectoryInto $srcDir $destDir } | Should -Throw "*a directory exists*"

        Test-Path "$srcDir\name" | Should -BeTrue
    }

    It "Throws when .local-conflict file already exists" {
        "dest" | Out-File "$destDir\a.txt"
        "source" | Out-File "$srcDir\a.txt"
        "old conflict" | Out-File "$destDir\a.txt.local-conflict"

        { Merge-DirectoryInto $srcDir $destDir } | Should -Throw "*Resolve existing conflicts*"

        Test-Path "$srcDir\a.txt" | Should -BeTrue
        Test-Path "$destDir\a.txt" | Should -BeTrue
        Test-Path "$destDir\a.txt.local-conflict" | Should -BeTrue
    }

    It "Recursively merges subdirectories" {
        mkdir "$destDir\sub" | Out-Null
        "dest file" | Out-File "$destDir\sub\from-dest.txt"
        mkdir "$srcDir\sub" | Out-Null
        "source file" | Out-File "$srcDir\sub\from-src.txt"

        Merge-DirectoryInto $srcDir $destDir

        Get-Content "$destDir\sub\from-dest.txt" | Should -BeLike "*dest file*"
        Get-Content "$destDir\sub\from-src.txt" | Should -BeLike "*source file*"
        Test-Path "$srcDir\sub\from-src.txt" | Should -BeFalse
        Test-Path "$srcDir\sub\from-dest.txt" | Should -BeFalse
    }

    It "Handles conflict inside nested subdirectory" {
        mkdir "$destDir\sub" | Out-Null
        "dest version" | Out-File "$destDir\sub\data.txt"
        mkdir "$srcDir\sub" | Out-Null
        "source version" | Out-File "$srcDir\sub\data.txt"

        Merge-DirectoryInto $srcDir $destDir 3>&1 | Out-Null

        Get-Content "$destDir\sub\data.txt" | Should -BeLike "*dest version*"
        Get-Content "$destDir\sub\data.txt.local-conflict" | Should -BeLike "*source version*"
        Test-Path "$srcDir\sub\data.txt" | Should -BeFalse
    }

    It "Moves source subdirectory when dest has no matching directory" {
        mkdir "$srcDir\newdir" | Out-Null
        "content" | Out-File "$srcDir\newdir\file.txt"

        Merge-DirectoryInto $srcDir $destDir

        Get-Content "$destDir\newdir\file.txt" | Should -BeLike "*content*"
        Test-Path "$srcDir\newdir" | Should -BeFalse
    }

    It "Leaves source subdirectory empty after recursive merge" {
        mkdir "$destDir\sub" | Out-Null
        mkdir "$srcDir\sub" | Out-Null
        "only in source" | Out-File "$srcDir\sub\file.txt"

        Merge-DirectoryInto $srcDir $destDir

        # The source subdir should have been removed after merge
        Test-Path "$srcDir\sub" | Should -BeFalse
        Get-Content "$destDir\sub\file.txt" | Should -BeLike "*only in source*"
    }
}
