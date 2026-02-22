# .SYNOPSIS
# Resolves the code coverage scope for a given test path.
# For a directory, returns the directory's absolute path.
# For a single test file, infers the corresponding production code file via naming convention.
# Falls back to RepoRoot if no production file is found.
param($PathToTest, $RepoRoot)

if (Test-Path -PathType Container $PathToTest) {
    return (Resolve-Path $PathToTest).Path
}

$guess = $PathToTest -replace ".tests.ps1", ".ps1"
$guessParent = Split-Path -Parent $guess
if ($guessParent -and (Test-Path -PathType Container $guessParent)) {
    $codeFile = & "$PSScriptRoot/Get-ContainingItem" (Split-Path -Leaf $guess) $guessParent
} else {
    $codeFile = $null
}
if ($null -ne $codeFile) {
    return $codeFile.FullName
} else {
    return $RepoRoot
}
