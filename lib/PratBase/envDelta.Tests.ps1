BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

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
            testValue_set2 = $env:testValue_set2
            testValue_set3 = $env:testValue_set3
            testValue_set4 = $env:testValue_set4
            testValue_cleared = $env:testValue_cleared
            testValue_cleared2 = $env:testValue_cleared2
            testValue_uncovered = $env:testValue_uncovered
        }
        $env:testValue_set = "set_foo"
        $env:testValue_set2 = "set2_foo"
        $env:testValue_set3 = "set3_foo"
        $env:testValue_set4 = "set4_foo"
        $env:testValue_cleared = $null
        $env:testValue_cleared2 = $null
        $env:testValue_uncovered = "uncovered_foo"

        return $prev
    }

    function popTestEnvironment($prev) {
        $env:testValue_set = $prev.testValue_set
        $env:testValue_set2 = $prev.testValue_set2
        $env:testValue_set3 = $prev.testValue_set3
        $env:testValue_set4 = $prev.testValue_set4
        $env:testValue_cleared = $prev.testValue_cleared
        $env:testValue_cleared2 = $prev.testValue_cleared2
        $env:testValue_uncovered = $prev.testValue_uncovered
    }
}

Describe "calculateEnvDelta" {
    It "finds items added in 'after'" {
        $before = @{
            test_unchanged = 1
            test_empty = ""
        }
        $after = @{
            test_added = 42

            test_unchanged = 1
            test_empty = ""
        }

        # Act
        $result = calculateEnvDelta $before $after

        # Assert
        $result.apply.Count | Should -Be 1
        $result.apply.test_added | Should -Be 42
        $result.prev.Count | Should -Be 1
        $result.prev.test_added | Should -Be ""
    }

    It "finds items changed in 'after'" {
        $before = @{
            test_changed = 2

            test_unchanged = 1
            test_empty = ""
        }
        $after = @{
            test_changed = 42

            test_unchanged = 1
            test_empty = ""
        }

        # Act
        $result = calculateEnvDelta $before $after

        # Assert
        $result.apply.Count | Should -Be 1
        $result.apply.test_changed | Should -Be 42
        $result.prev.Count | Should -Be 1
        $result.prev.test_changed | Should -Be 2
    }

    It "specially handles items deleted in 'after'" {
        $before = @{
            test_afterWillEmpty = 2
            test_afterWontMention = 3

            test_unchanged = 1
            test_empty = ""
        }
        $after = @{
            test_afterWillEmpty = ""

            test_unchanged = 1
            test_empty = ""
        }

        # Act
        $result = calculateEnvDelta $before $after
        $result2 = calculateEnvDelta $before $after -MissingInAfterMeansDeletion

        # Assert
        $result.apply.Count | Should -Be 1
        $result.apply.test_afterWillEmpty | Should -Be ""
        $result.prev.Count | Should -Be 1
        $result.prev.test_afterWillEmpty | Should -Be 2

        $result2.apply.Count | Should -Be 2
        $result2.apply.test_afterWillEmpty | Should -Be ""
        $result2.apply.test_afterWontMention | Should -Be ""
        $result2.prev.Count | Should -Be 2
        $result2.prev.test_afterWillEmpty | Should -Be 2
        $result2.prev.test_afterWontMention | Should -Be 3
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

            $fn = createTestFile $batchScript ".bat"

            # Act
            $result = Export-EnvDeltaFromInvokedBatchScript $fn

            # Assert

            # Write-DebugValue $result.apply '$result.apply'
            # Write-DebugValue $result.prev '$result.prev'
            $result.apply.testValue_set     | Should -Be "set_updated"
            $result.prev. testValue_set     | Should -Be "set_foo"
            $result.apply.testValue_set2    | Should -Be ""
            $result.prev. testValue_set2    | Should -Be "set2_foo"
            $result.apply.testValue_cleared | Should -Be "cleared_set"
            $result.prev. testValue_cleared | Should -Be ""

            # Sanity-check the empty-string value for set2:
            $result.apply.Contains('testValue_set2') | Should -BeTrue

            # Values that were untouched / unmodified, should be ignored
            $result.apply.Contains('testValue_set3')     | Should -BeFalse
            $result.prev. Contains('testValue_set3')     | Should -BeFalse
            $result.apply.Contains('testValue_set4')     | Should -BeFalse
            $result.prev. Contains('testValue_set4')     | Should -BeFalse
            $result.apply.Contains('testValue_cleared2') | Should -BeFalse
            $result.prev. Contains('testValue_cleared2') | Should -BeFalse

            # There should be no other values in these tables, since the script only changed these 3.
            $result.apply.Count | Should -Be 3
            $result.prev.Count | Should -Be 3 
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
            $fn = createTestFile $batchScript ".bat"

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
            $fn = createTestFile $batchScript ".bat"

            $testEnvironment2 = Export-EnvDeltaFromInvokedBatchScript $fn
            $testScript = {
                echo "hi: $($env:testValue_set), $($env:testValue_set2), $($env:testValue_cleared), $($env:testValue_set4)"
            }
            # Write-DebugValue $testEnvironment2 '$testEnvironment2'

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
    It "Will, incidentally, restore changes that the called script makes TO COVERED env-vars" {
        $prev = pushTestEnvironment
        try {
            $batchScript = @"
                set testValue_set=set_updated
                exit /b 0
"@
            $fn = createTestFile $batchScript ".bat"

            $testEnvironment2 = Export-EnvDeltaFromInvokedBatchScript $fn
            $testScript = {
                $env:testValue_set="set_updated2"
                echo "hi: $($env:testValue_set)"
            }

            # Act
            $result = Invoke-CommandWithEnvDelta $testScript $testEnvironment2

            # Assert
            $result | Should -Be "hi: set_updated2"
            $env:testValue_set | Should -Be "set_foo"
        } finally {
            popTestEnvironment $prev
        }
    }
    It "Will NOT restore changes that the called script makes to NON-COVERED env-vars" {
        # For this reason, $testScript code should either avoid modifying env-vars, or save and restore all env-vars itself if that's appropriate.
        # TODO: Consider whether to include that behavior by default.

        $prev = pushTestEnvironment
        try {
            # The key thing about this batch script is it does NOT change $env:testValue_uncovered
            $batchScript = @"
                set testValue_set=set_updated
                exit /b 0
"@
            $fn = createTestFile $batchScript ".bat"

            $testEnvironment2 = Export-EnvDeltaFromInvokedBatchScript $fn
            $testScript = {
                $env:testValue_uncovered="uncovered_updated"
                echo "hi: $($env:testValue_set), $($env:testValue_uncovered)"
            }

            # Act
            $result = Invoke-CommandWithEnvDelta $testScript $testEnvironment2

            # Assert
            $result | Should -Be "hi: set_updated, uncovered_updated"
            $env:testValue_set | Should -Be "set_foo"

            $env:testValue_uncovered | Should -Be "uncovered_updated" # Was NOT restored to "uncovered_foo"
        } finally {
            popTestEnvironment $prev
        }
    }
    It "Supports $null envdelta" {
        $prev = pushTestEnvironment
        try {
            $testScript = {
                echo "hi: $($env:testValue_set)"
            }

            # Act
            $result = Invoke-CommandWithEnvDelta $testScript $null 

            # Assert
            $result | Should -Be "hi: set_foo"
            $env:testValue_set | Should -Be "set_foo"
        } finally {
            popTestEnvironment $prev
        }
    }
}


Describe "Get-CachedEnvDelta" {
    It "Loads the structure from a file" {
        $cacheFile = @"
        @{
            'apply' = @{'testValue_set' = 'set_updated77'}
            'prev'  = @{'testValue_set' = 'set_foo'}
        }
"@
        # Write-DebugValue $cacheFile

        $fn = createTestFile $cacheFile ".ps1"

        # Act
        $result = Get-CachedEnvDelta $fn

        # Assert
        $testScript = {
            echo "hi: $($env:testValue_set)"
        }
        $output = Invoke-CommandWithEnvDelta $testScript $result
        $output | Should -Be "hi: set_updated77"
    }
    It "Handles a particular format of empty case without throwing" {
        $cacheFile = @"
        @{
            'apply' = @{}
            'prev'  = @{}
        }
"@

        $fn = createTestFile $cacheFile ".ps1"

        # Act
        $result = Get-CachedEnvDelta $fn

        # Assert
        $result.prev.Keys.Count | Should -Be 0
    }
}

