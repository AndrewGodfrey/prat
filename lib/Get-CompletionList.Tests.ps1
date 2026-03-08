Describe "Get-CompletionList" {
    BeforeAll {
        Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
        $script:scriptPath = "$PSScriptRoot/Get-CompletionList.ps1"
    }

    Context "cache is fresh (< 1 day old)" {
        It "returns cached content without recalculating" {
            $cacheDir = "TestDrive:\fresh"
            New-Item -ItemType Directory -Path $cacheDir | Out-Null
            "@('cached-value')" | Out-File "$cacheDir\myList.ps1"

            $now = [datetime]::Now  # file just written, age ~0
            $calculator = { throw "should not be called" }

            $result = & $script:scriptPath -listId "myList" -cacheDir $cacheDir -now $now -calculator $calculator

            $result | Should -Be 'cached-value'
        }
    }

    Context "cache is stale (> 1 day old)" {
        It "recalculates and updates the cache" {
            $cacheDir = "TestDrive:\stale"
            New-Item -ItemType Directory -Path $cacheDir | Out-Null
            "@('stale-value')" | Out-File "$cacheDir\myList.ps1"

            $now = [datetime]::Now.AddDays(2)  # simulate 2 days later
            $calculator = { param($id) @('fresh-value') }

            # Act
            $result = & $script:scriptPath -listId "myList" -cacheDir $cacheDir -now $now -calculator $calculator

            # Assert
            $result | Should -Be 'fresh-value'
            $fromCache = & $script:scriptPath -listId "myList" -cacheDir $cacheDir -now ([datetime]::Now) -calculator { throw "should use cache" }
            $fromCache | Should -Be 'fresh-value'
        }
    }

    Context "no cache file exists" {
        It "calculates and caches the result" {
            $cacheDir = "TestDrive:\empty"
            # Don't pre-create dir; script should create it

            $now = [datetime]::Now
            $calculator = { param($id) @('computed-value') }

            $result = & $script:scriptPath -listId "myList" -cacheDir $cacheDir -now $now -calculator $calculator

            # Assert
            $result | Should -Be 'computed-value'
            $fromCache = & $script:scriptPath -listId "myList" -cacheDir $cacheDir -now ([datetime]::Now) -calculator { throw "should use cache" }
            $fromCache | Should -Be 'computed-value'
        }
    }
}
