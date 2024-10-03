BeforeAll {
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

Describe "Open-CodebaseWorkspace" {
    It "runs the given script with a temporary environment" {
        $prev = pushTestEnvironment
        try {
            $cacheFile = @"
            [ordered] @{
                'apply' = [ordered] @{'testValue_set' = 'set_updated77'}
                'prev'  = [ordered] @{'testValue_set' = 'foo'}
            }
"@
            $cbt = @{
                cachedEnvDelta = (createTestFile $cacheFile ".ps1")
            }

            # Act
            $result = Open-CodebaseWorkspace {echo "hi: $($env:testValue_set)"} $cbt

            # Assert
            $result | Should -Be "hi: set_updated77"
            $env:testValue_set | Should -Be "set_foo"
        } finally {
            popTestEnvironment $prev
        }
    }
}