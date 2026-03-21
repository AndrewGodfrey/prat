BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
    $env:path += ";$PSScriptRoot/.."

    $script:resolvePratLibFile = "$PSScriptRoot/../Resolve-PratLibFile.ps1"

    # Write a fake Get-CodebaseLayers.ps1 returning a specific layer list, into the given dir.
    function writeGetCodebaseLayers([string]$dir, [hashtable[]]$layers) {
        $layerExprs = $layers | ForEach-Object {
            $name = $_.Name
            $path = $_.Path.Replace('\', '/')
            "@{Name = '$name'; Path = '$path'}"
        }
        $body = "@($($layerExprs -join ', '))"
        Set-Content "$dir/Get-CodebaseLayers.ps1" $body
    }

    function withFakeLayers([string]$dir, [scriptblock]$test) {
        $savedPath = $env:PATH
        $env:PATH = "$dir;$env:PATH"
        try { & $test }
        finally { $env:PATH = $savedPath }
    }
}

Describe "Resolve-PratLibFile - deployEnv shim lookup" {
    # These tests verify that Resolve-PratLibFile "lib/deployEnv.ps1" resolves to the
    # most-specific layer's shim, given different overlay configurations.

    It "resolves to prat's deployEnv_prat.ps1 when only prat layer" {
        $dir = (New-Item -ItemType Directory -Path "TestDrive:\gcl-prat").FullName
        writeGetCodebaseLayers $dir @(@{Name = 'prat'; Path = "$home/prat" })

        withFakeLayers $dir {
            $result = & $script:resolvePratLibFile "lib/deployEnv.ps1"

            $result | Should -Not -BeNull
            (Split-Path -Leaf $result) | Should -Be "deployEnv_prat.ps1"
        }
    }

    It "resolves to prefs's deployEnv_prefs.ps1 when prefs+prat layers" {
        $dir = (New-Item -ItemType Directory -Path "TestDrive:\gcl-prefs").FullName
        writeGetCodebaseLayers $dir @(
            @{Name = 'prefs'; Path = "$home/prefs" },
            @{Name = 'prat'; Path = "$home/prat" }
        )

        withFakeLayers $dir {
            $result = & $script:resolvePratLibFile "lib/deployEnv.ps1"

            $result | Should -Not -BeNull
            (Split-Path -Leaf $result) | Should -Be "deployEnv_prefs.ps1"
        }
    }

    It "resolves to de's deployEnv_de.ps1 when de+prefs+prat layers" {
        $dir = (New-Item -ItemType Directory -Path "TestDrive:\gcl-de").FullName
        writeGetCodebaseLayers $dir @(
            @{Name = 'de'; Path = "$home/de" },
            @{Name = 'prefs'; Path = "$home/prefs" },
            @{Name = 'prat'; Path = "$home/prat" }
        )

        withFakeLayers $dir {
            $result = & $script:resolvePratLibFile "lib/deployEnv.ps1"

            $result | Should -Not -BeNull
            (Split-Path -Leaf $result) | Should -Be "deployEnv_de.ps1"
        }
    }
}
