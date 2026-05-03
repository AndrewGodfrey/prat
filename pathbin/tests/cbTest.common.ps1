# Test helper: creates a temp file on TestDrive with the given content and extension.
[int] $testFileNum = 0
function createTestFile($data, $extension) {
    $testFileNum += 1
    $tempFile = "$TestDrive\test.$testFileNum$extension"
    $data | Out-File -Encoding ASCII $tempFile
    return $tempFile
}
