BeforeAll {
    . "$PSScriptRoot/Resolve-JunctionInPath.ps1"
    # TestDrive: is a PowerShell provider path, which .NET file APIs and external tools reject.
    $script:testRoot = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
}

Describe "Resolve-JunctionInPath" {
    BeforeAll {
        # Distinct subdir per test, since TestDrive is shared within the Describe. Junction creation doesn't need admin.
        function New-JunctionFixture([string] $name) {
            $target = (New-Item -ItemType Directory -Path "$testRoot/$name/realTarget").FullName
            $junction = (New-Item -ItemType Junction -Path "$testRoot/$name/link" -Target $target).FullName
            return @{ Target = $target; Junction = $junction }
        }
    }

    It "replaces a junction ancestor with its target" {
        $f = New-JunctionFixture "ancestor"

        Resolve-JunctionInPath "$($f.Junction)\sub\file.txt" | Should -Be "$($f.Target)\sub\file.txt"
    }

    It "resolves a path that is itself a junction" {
        $f = New-JunctionFixture "itself"

        Resolve-JunctionInPath $f.Junction | Should -Be $f.Target
    }

    It "resolves a path under a junction that doesn't exist yet" {
        $f = New-JunctionFixture "missing"

        Resolve-JunctionInPath "$($f.Junction)\new\file.txt" | Should -Be "$($f.Target)\new\file.txt"
    }

    It "returns a path with no junction in it unchanged" {
        $f = New-JunctionFixture "none"

        Resolve-JunctionInPath "$($f.Target)\file.txt" | Should -Be "$($f.Target)\file.txt"
    }
}
