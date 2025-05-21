BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    function AssertCommonGitArgs {
        if ($args[0] -ne '-C') { throw }
        if ($args[1] -ne 'c:\foo\git') { throw }
    }
    function MockGitMergeBase {
        AssertCommonGitArgs @args
        if ($args[2] -ne 'merge-base') { throw }
        $a = [int] $args[3]
        $b = [int] $args[4]

        if ($a -eq 1) { return $null }
        if ($b -eq 1) { return $null }
        if ($a -eq 4) { return 999 }
        if ($a -lt $b) { return $a }
        return $b
    }
}

Describe "Get-CurrentGitForkpoint" {
    It "Should return a forkpoint" {
        Mock git {
            AssertCommonGitArgs @args
            if ($args[2] -eq 'merge-base') {
                return '1234'
            }
            if ($args[2] -eq 'log') {
                return '2023-10-01T12:00:00+00:00'
            }
            throw "Unexpected git command: $args"
        }

        $repoRoot = "c:\foo\git"
        $forkpoint = Get-CurrentGitForkpoint $repoRoot
        $forkpoint.forkpointType | Should -Be 'git'
        $forkpoint.commitId | Should -Be '1234'
        $forkpoint.repoRoot | Should -Be $repoRoot
        $forkpoint.authorDate | Should -BeOfType [datetime]
    }
    It "Handles detached-head state" {
        Mock git {
            AssertCommonGitArgs @args
            switch ($args[2]) {
                'merge-base' {
                    if ($args[-1] -ne 'HEAD') { throw }
                    if ($args[-2] -ne 'origin/main') { throw }
                    if ($args[3] -eq '--fork-point') {
                        return $null
                    }
                    return '1234'
                }
                'log' {
                    return '2023-10-01T12:00:00+00:00'
                }
                default {
                    throw "Unexpected git command: $args"
                }
            }
        }

        $repoRoot = "c:\foo\git"
        $forkpoint = Get-CurrentGitForkpoint $repoRoot
        $forkpoint.forkpointType | Should -Be 'git'
        $forkpoint.commitId | Should -Be '1234'
        $forkpoint.repoRoot | Should -Be $repoRoot
        $forkpoint.authorDate | Should -BeOfType [datetime]
    }
}

Describe "Get-ForkpointRelationship" {
    It "Should return equal for the same commitId" {
        Mock git { throw }
        $fp = @{
            forkpointType = 'git'
            commitId = '1234'
            repoRoot = 'c:\foo\git'
        }
        Get-ForkpointRelationship $fp $fp | Should -Be 'equal'
    }

    It "Throws if forkpointTypes don't match" {
        Mock git { throw }
        $a = @{ forkpointType = 'git' }
        $b = @{ forkpointType = 'hg' }
        {Get-ForkpointRelationship $a $b} | Should -Throw "Internal error - comparing forkpoints of different types"
    }

    It "Throws if repoRoots don't match" {
        Mock git { throw }
        $a = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git' }
        $b = @{ forkpointType = 'git'; repoRoot = 'c:\bar\git' }
        {Get-ForkpointRelationship $a $b} | Should -Throw "Internal error - comparing forkpoints from different repo roots"
    }

    It "Only knows about git" {
        Mock git { throw }
        $fp = @{ forkpointType = 'hg'; repoRoot = 'c:\foo\git' }
        {Get-ForkpointRelationship $fp $fp} | Should -Throw "Internal error - unsupported forkpoint type 'hg'"
    }

    Context "Gets as far as calling git" {
        BeforeEach {
            function RunTest($PreviousCommit, $CurrentCommit) {
                Mock git { MockGitMergeBase @args }
                $previousForkpoint = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = "$PreviousCommit" }
                $currentForkpoint = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = "$CurrentCommit" }
                Get-ForkpointRelationship $previousForkpoint $currentForkpoint
            }
        }
        It "Uses git merge-base to classify - unrelated case" {
            RunTest -PreviousCommit 1 -CurrentCommit 1235 | Should -Be 'unrelated'
        }

        It "Uses git merge-base to classify - complex case" {
            RunTest -PreviousCommit 4 -CurrentCommit 1235 | Should -Be 'complex'
        }

        It "Uses git merge-base to classify - currentIsOlder" {
            RunTest -PreviousCommit 3 -CurrentCommit 2 | Should -Be 'currentIsOlder'
        }

        It "Uses git merge-base to classify - currentIsNewer" {
            RunTest -PreviousCommit 2 -CurrentCommit 3 | Should -Be 'currentIsNewer'
        }
    }
}

Describe "Get-ForkpointCacheIsValid" {
    BeforeEach {
        function RunTest($PreviousCommit, $CurrentCommit) {
            Mock git { MockGitMergeBase @args }
            $current = @{
                forkpointType = 'git'
                commitId = "$currentCommit"
                repoRoot = 'c:\foo\git'
            }
            $testForkpoint = $PSScriptRoot + '\test\forkpointCacheTest_commit' + $previousCommit + '.ps1'
            Get-ForkpointCacheIsValid $testForkpoint $current
        }
    }
    It "Returns false, when the current forkpoint is newer" {
        RunTest -PreviousCommit 2 -CurrentCommit 3 | Should -Be $false
    }
    It "Returns true, when the current forkpoint is equal" {
        RunTest -PreviousCommit 2 -CurrentCommit 2 | Should -Be $true
    }
    It "Returns false and warns, when the current forkpoint has no relationship" {
        RunTest -PreviousCommit 2 -CurrentCommit 1 3>&1 | Tee-Object -Variable warnings
        $warnings[0] | Should -Be "Can't find common ancestor between cached forkpoint and current forkpoint"
        $warnings[1] | Should -Be $false
    }
    It "Returns true and warns, when the current forkpoint is older" {
        RunTest -PreviousCommit 3 -CurrentCommit 2 3>&1 | Tee-Object -Variable warnings
        $warnings[0] | Should -Be "Current forkpoint is older than cached forkpoint. Reusing cache."
        $warnings[1] | Should -Be $true
    }
}

Describe "Set-ForkpointCache" {
    It "Creates directories and writes a file" {
        $currentForkpoint = @{
            forkpointType = 'git'
            commitId = '1234'
            repoRoot = 'c:\foo\git'
        }
        $fn = "c:\foo\bar.ps1"
        Mock ConvertTo-Expression {
            if ($InputObject -ne $currentForkpoint) { throw } 
            return "bar"
        } -Verifiable
        Mock New-FolderAndParents { if ($path -ne 'c:\foo') { throw $path } } -Verifiable
        Mock Set-Content { 
            if ($Value -ne 'bar') { throw "Value: $Value"}
            if ($LiteralPath -ne $fn) { throw "LiteralPath: $LiteralPath" }
        } -Verifiable

        Set-ForkpointCache $fn $currentForkpoint

        Should -Invoke ConvertTo-Expression -Times 1
        Should -Invoke New-FolderAndParents -Times 1
        Should -Invoke Set-Content -Times 1
    }
}