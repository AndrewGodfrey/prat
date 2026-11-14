BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
    [int] $testFileNum = 0
    function createTestFile($data, $extension) {
        $testFileNum += 1
        $tempFile = "$TestDrive\test.$testFileNum$extension"
        $data | Out-File -Encoding ASCII $tempFile
        return $tempFile
    }
    function pushTestEnvironment {
        $prev = @{
            testValue_set = $env:testValue_set
        }
        $env:testValue_set = "set_foo"
        return $prev
    }

    function popTestEnvironment($prev) {
        $env:testValue_set = $prev.testValue_set
    }
}

Describe "Open-Workspace" {
    It "makes the resolved project available to a registry workspace scriptblock" {
        Mock Write-Host {}
        $checkoutRoot = (Get-Item 'TestDrive:\').FullName.TrimEnd('\')
        $profileFile = Join-Path $checkoutRoot 'codebaseProfile_test.ps1'
        "@{ '.' = @{ repos = @{ myrepo = @{ root = '$checkoutRoot'; workspace = { `$project.root } } } } }" |
            Set-Content $profileFile
        Mock Get-RepoProfileFiles -ModuleName PratBase { @($profileFile) }

        $workspaceProject = Get-PratProject $checkoutRoot
        $workspaceProject.id | Should -Be 'myrepo'
        Mock Get-PratProject { $workspaceProject }

        Open-Workspace | Should -Be $checkoutRoot
    }

    It "runs the given script with a temporary environment" {
        Mock Write-Host {}
        $prev = pushTestEnvironment
        try {
            $cacheFile = @"
            [ordered] @{
                'apply' = [ordered] @{'testValue_set' = 'set_updated77'}
                'prev'  = [ordered] @{'testValue_set' = 'foo'}
            }
"@
            $project = @{
                cachedEnvDelta = (createTestFile $cacheFile ".ps1")
            }

            # Act
            $result = Open-Workspace {echo "hi: $($env:testValue_set)"} $project

            # Assert
            $result | Should -Be "hi: set_updated77"
            $env:testValue_set | Should -Be "set_foo"
        } finally {
            popTestEnvironment $prev
        }
    }
}