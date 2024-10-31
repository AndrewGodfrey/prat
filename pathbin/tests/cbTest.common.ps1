# Test helpers for use in testing codebase-related functions.

[int] $testFileNum = 0
function createTestFile($data, $extension) {
    $testFileNum += 1
    $tempFile = "$TestDrive\test.$testFileNum$extension"
    $data | Out-File -Encoding ASCII $tempFile
    return $tempFile
}
function pushTestEnvironment {
    $prev = @{
        testEnvvar = $env:testEnvvar
        pwd = $pwd
    }
    $env:testEnvvar = "testEnvvar"
    Set-Location $PSScriptRoot/testCb
    return $prev
}

function popTestEnvironment($prev) {
    $env:testEnvvar = $prev.testEnvvar
    set-location $prev.pwd
}
