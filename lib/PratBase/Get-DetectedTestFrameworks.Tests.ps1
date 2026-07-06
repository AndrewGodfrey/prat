BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-DetectedTestFrameworks" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
    }

    It "detects pytest via pyproject.toml" {
        New-Item -ItemType Directory "$root/pyProj" -Force | Out-Null
        New-Item "$root/pyProj/pyproject.toml" -ItemType File | Out-Null

        @(Get-DetectedTestFrameworks "$root/pyProj") | Should -Be @('pytest')
    }

    It "detects pytest via a top-level test_*.py file, even with no pyproject.toml" {
        New-Item -ItemType Directory "$root/plainPyProj" -Force | Out-Null
        New-Item "$root/plainPyProj/test_foo.py" -ItemType File | Out-Null

        @(Get-DetectedTestFrameworks "$root/plainPyProj") | Should -Be @('pytest')
    }

    It "detects pytest via a top-level conftest.py, even with no pyproject.toml" {
        New-Item -ItemType Directory "$root/conftestOnlyProj" -Force | Out-Null
        New-Item "$root/conftestOnlyProj/conftest.py" -ItemType File | Out-Null

        @(Get-DetectedTestFrameworks "$root/conftestOnlyProj") | Should -Be @('pytest')
    }

    It "detects dotnet via a nested *.Tests.csproj" {
        New-Item -ItemType Directory "$root/dotnetProj/Foo.Tests" -Force | Out-Null
        New-Item "$root/dotnetProj/Foo.Tests/Foo.Tests.csproj" -ItemType File | Out-Null

        @(Get-DetectedTestFrameworks "$root/dotnetProj") | Should -Be @('dotnet')
    }

    It "returns both markers, pytest first, when both are present" {
        New-Item -ItemType Directory "$root/bothProj/Foo.Tests" -Force | Out-Null
        New-Item "$root/bothProj/pyproject.toml" -ItemType File | Out-Null
        New-Item "$root/bothProj/Foo.Tests/Foo.Tests.csproj" -ItemType File | Out-Null

        $result = @(Get-DetectedTestFrameworks "$root/bothProj")

        $result.Count | Should -Be 2
        $result[0] | Should -Be 'pytest'
        $result[1] | Should -Be 'dotnet'
    }

    It "returns an empty array when no marker is found" {
        New-Item -ItemType Directory "$root/emptyProj" -Force | Out-Null

        @(Get-DetectedTestFrameworks "$root/emptyProj").Count | Should -Be 0
    }
}
