BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    [int] $testFileNum = 0
    function createTestFile($data, $extension = ".bat") {
        $testFileNum += 1

        $tempFile = "$TestDrive\test.$testFileNum$extension"

        $data | Out-File -Encoding ASCII $tempFile

        return $tempFile
    }

    function pushTestEnvironment {
        $prev = @{
            testValue_set = $env:testValue_set
            testValue_set2 = $env:testValue_set2
            testValue_set3 = $env:testValue_set3
            testValue_set4 = $env:testValue_set4
            testValue_cleared = $env:testValue_cleared
            testValue_cleared2 = $env:testValue_cleared2
        }
        $env:testValue_set = "set_foo"
        $env:testValue_set2 = "set2_foo"
        $env:testValue_set3 = "set3_foo"
        $env:testValue_set4 = "set4_foo"
        $env:testValue_cleared = $null
        $env:testValue_cleared2 = $null

        return $prev
    }

    function popTestEnvironment($prev) {
        $env:testValue_set = $prev.testValue_set
        $env:testValue_set2 = $prev.testValue_set2
        $env:testValue_set3 = $prev.testValue_set3
        $env:testValue_set4 = $prev.testValue_set4
        $env:testValue_cleared = $prev.testValue_cleared
        $env:testValue_cleared2 = $prev.testValue_cleared2
    }
}

Describe "captureCurrentEnv" {
    It "captures env: as a table of strings" {
        $prev = pushTestEnvironment
        try {
            # Act
            $result = captureCurrentEnv

            # Assert
            $result.testValue_set | Should -Be "set_foo"
            $result.testValue_cleared | Should -BeNull
        } finally {
            popTestEnvironment $prev
        }
    }
}

Describe "Export-EnvDeltaFromInvokedBatchScript" {
    It "Captures changes a batch script makes to environment variables" {
        $prev = pushTestEnvironment
        try {
            # Watch out for whitespaces here - before and after the "=", all spaces matter including trailing spaces.
            $batchScript = @"
                set testValue_set=set_updated
                set testValue_set2=
                set testValue_set3=set3_foo
                set testValue_cleared=cleared_set
                exit /b 0
"@

            $fn = createTestFile $batchScript

            # Act
            $result = Export-EnvDeltaFromInvokedBatchScript $fn

            # Assert
            Write-DebugValue $result.apply "result.apply"
            Write-DebugValue $result.revert "result.revert"
            $result.apply.testValue_set       | Should -Be "set_updated"
            $result.revert.testValue_set      | Should -Be "set_foo"
            $result.apply.testValue_set2      | Should -Be ""
            $result.revert.testValue_set2     | Should -Be "set2_foo"
            $result.apply.testValue_cleared   | Should -Be "cleared_set"
            $result.revert.testValue_cleared  | Should -Be ""

            # Sanity-check the empty-string value for set2:
            $result.apply.Contains('testValue_set2') | Should -BeTrue

            # Values that were untouched / unmodified, should be ignored
            $result.apply. Contains('testValue_set3') | Should -BeFalse
            $result.revert.Contains('testValue_set3') | Should -BeFalse
            $result.apply. Contains('testValue_set4') | Should -BeFalse
            $result.revert.Contains('testValue_set4') | Should -BeFalse
            $result.apply. Contains('testValue_cleared2') | Should -BeFalse
            $result.revert.Contains('testValue_cleared2') | Should -BeFalse

            # There should be no other values in these tables, since the script only changed these 3.
            $result.apply.Count | Should -Be 3
            $result.revert.Count | Should -Be 3 
        } finally {
            popTestEnvironment $prev
        }
    }
    It "Throws on script failure, unless told otherwise" {
        $prev = pushTestEnvironment
        try {
            $batchScript = @"
                set testValue_set=set_updated
                exit /b 1
"@
            # Act
            $fn = createTestFile $batchScript

            # Assert
            {Export-EnvDeltaFromInvokedBatchScript $fn} | Should -Throw -ExpectedMessage "batch script failed: error code: 1"
            {Export-EnvDeltaFromInvokedBatchScript $fn -checkExitCode:$false} | Should -Not -Throw
        } finally {
            popTestEnvironment $prev
        }
    }
}

Describe "Invoke-CommandWithEnvDelta" {
    It "Runs a scriptblock with the given environment temporarily applied" {
        $prev = pushTestEnvironment
        try {
            $batchScript = @"
                set testValue_set=set_updated
                set testValue_set2=
                set testValue_set3=set3_foo
                set testValue_cleared=cleared_set
                exit /b 0
"@
            $fn = createTestFile $batchScript

            $testEnvironment2 = Export-EnvDeltaFromInvokedBatchScript $fn
            $testScript = {
                echo "hi: $($env:testValue_set), $($env:testValue_set2), $($env:testValue_cleared), $($env:testValue_set4)"
            }

            # Act
            $result = Invoke-CommandWithEnvDelta $testScript $testEnvironment2

            # Assert
            $result | Should -Be "hi: set_updated, , cleared_set, set4_foo"

            $env:testValue_set | Should -Be "set_foo"
            $env:testValue_set2 | Should -Be "set2_foo"
            $env:testValue_set3 | Should -Be "set3_foo"
            $env:testValue_set4 | Should -Be "set4_foo"
            $env:testValue_cleared | Should -BeNull 
            $env:testValue_cleared2 | Should -BeNull
        } finally {
            popTestEnvironment $prev
        }
    }
}
