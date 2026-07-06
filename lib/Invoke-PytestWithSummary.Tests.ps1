BeforeAll {
    . "$PSScriptRoot/Invoke-PytestWithSummary.ps1"
}

Describe "Get-InferredPytestModules" {
    It "includes a top-level .py file, by base name" {
        $dir = "TestDrive:/plainFile"
        New-Item $dir -ItemType Directory | Out-Null
        New-Item "$dir/foo.py" -ItemType File | Out-Null

        Get-InferredPytestModules $dir | Should -Be @('foo')
    }

    It "excludes test_*.py files" {
        $dir = "TestDrive:/excludeTest"
        New-Item $dir -ItemType Directory | Out-Null
        New-Item "$dir/foo.py" -ItemType File | Out-Null
        New-Item "$dir/test_foo.py" -ItemType File | Out-Null

        Get-InferredPytestModules $dir | Should -Be @('foo')
    }

    It "excludes conftest.py" {
        $dir = "TestDrive:/excludeConftest"
        New-Item $dir -ItemType Directory | Out-Null
        New-Item "$dir/foo.py" -ItemType File | Out-Null
        New-Item "$dir/conftest.py" -ItemType File | Out-Null

        Get-InferredPytestModules $dir | Should -Be @('foo')
    }

    It "includes a top-level directory containing __init__.py, by directory name" {
        $dir = "TestDrive:/withPackage"
        New-Item "$dir/providers" -ItemType Directory -Force | Out-Null
        New-Item "$dir/providers/__init__.py" -ItemType File | Out-Null
        New-Item "$dir/providers/impl.py" -ItemType File | Out-Null

        Get-InferredPytestModules $dir | Should -Be @('providers')
    }

    It "excludes a top-level directory without __init__.py" {
        $dir = "TestDrive:/withoutInit"
        New-Item "$dir/notAPackage" -ItemType Directory -Force | Out-Null
        New-Item "$dir/notAPackage/impl.py" -ItemType File | Out-Null

        Get-InferredPytestModules $dir | Should -Be @()
    }

    It "returns an empty list for a directory with no modules" {
        $dir = "TestDrive:/empty"
        New-Item $dir -ItemType Directory | Out-Null

        Get-InferredPytestModules $dir | Should -Be @()
    }

    It "matches a real-world layout (mixed files, packages, tests)" {
        $dir = "TestDrive:/realWorld"
        New-Item $dir -ItemType Directory | Out-Null
        foreach ($f in @('main.py', 'display.py', 'download_data.py', 'test_main.py', 'conftest.py')) {
            New-Item "$dir/$f" -ItemType File | Out-Null
        }
        New-Item "$dir/providers" -ItemType Directory | Out-Null
        New-Item "$dir/providers/__init__.py" -ItemType File | Out-Null

        $result = Get-InferredPytestModules $dir
        Compare-Object $result @('main', 'display', 'download_data', 'providers') | Should -BeNullOrEmpty
    }
}
