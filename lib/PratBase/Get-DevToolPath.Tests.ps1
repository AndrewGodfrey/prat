BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-DevToolRegistry" {
    InModuleScope PratBase {
        BeforeEach {
            $dir = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
        }

        It "returns empty hashtable for null file list" {
            $result = Get-DevToolRegistry $null
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        It "returns empty hashtable for empty file list" {
            $result = Get-DevToolRegistry @()
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        Context "single file" {
            BeforeEach {
                "@{ nano = 'C:/git/nano'; ripgrep = 'C:/tools/rg' }" | Out-File "TestDrive:\single\reg.ps1" -Force
            }

            BeforeAll { New-Item -ItemType Directory -Force "TestDrive:\single" | Out-Null }

            It "returns path for a known tool" {
                (Get-DevToolRegistry @("$dir/single/reg.ps1"))["nano"] | Should -Be "C:/git/nano"
            }

            It "returns null for an unknown tool" {
                (Get-DevToolRegistry @("$dir/single/reg.ps1"))["other"] | Should -BeNull
            }

            It "includes all tools from the file" {
                $result = Get-DevToolRegistry @("$dir/single/reg.ps1")
                $result["ripgrep"] | Should -Be "C:/tools/rg"
            }
        }

        Context "multiple files" {
            BeforeAll { New-Item -ItemType Directory -Force "TestDrive:\multi" | Out-Null }

            Context "overlapping key — first file wins" {
                BeforeEach {
                    "@{ nano = 'C:/git/nano-de' }"   | Out-File "TestDrive:\multi\de.ps1"   -Force
                    "@{ nano = 'C:/git/nano-prat' }" | Out-File "TestDrive:\multi\prat.ps1" -Force
                }

                It "uses the value from the higher-priority (first) file" {
                    (Get-DevToolRegistry @("$dir/multi/de.ps1", "$dir/multi/prat.ps1"))["nano"] |
                        Should -Be "C:/git/nano-de"
                }
            }

            Context "non-overlapping keys — additive" {
                BeforeEach {
                    "@{ nano = 'C:/git/nano' }"    | Out-File "TestDrive:\multi\de.ps1"   -Force
                    "@{ ripgrep = 'C:/tools/rg' }" | Out-File "TestDrive:\multi\prat.ps1" -Force
                }

                It "finds a tool defined only in the first file" {
                    (Get-DevToolRegistry @("$dir/multi/de.ps1", "$dir/multi/prat.ps1"))["nano"] |
                        Should -Be "C:/git/nano"
                }

                It "finds a tool defined only in the second file" {
                    (Get-DevToolRegistry @("$dir/multi/de.ps1", "$dir/multi/prat.ps1"))["ripgrep"] |
                        Should -Be "C:/tools/rg"
                }
            }
        }
    }
}
