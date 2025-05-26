BeforeAll {
    . $PSScriptRoot\cbTest.common.ps1

    # I don't understand why this test needs me to edit path, and e.g. Compare-Hash.Tests.ps1 doesn't.
    # Without this, tests work fine from command line, and in vscode "Debug Test" also works.
    # But in vscode "Run Test" it fails with "The term 'Deploy-Codebase' is not recognized [...]"
    $env:path += ";$PSScriptRoot\.."
}

Describe "Deploy-Codebase" {
    It "runs the 'deploy' script for the 'testCb' codebase" {
        $prev = pushTestEnvironment
        try {
            $env:testenvvar = 'foo'
            
            # Act
            $result = Deploy-Codebase

            # Assert
            $result | Should -Be "testCb: deploy: bar"
        } finally {
            popTestEnvironment $prev
        }
    }
}