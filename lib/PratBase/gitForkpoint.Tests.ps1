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

    It "Uses git merge-base to classify - unrelated case" {
        Mock git { MockGitMergeBase @args }
        $a = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '1' }
        $b = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '1235' }
        Get-ForkpointRelationship $a $b | Should -Be 'unrelated'
    }

    It "Uses git merge-base to classify - complex case" {
        Mock git { MockGitMergeBase @args }
        $a = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '4' }
        $b = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '1235' }
        Get-ForkpointRelationship $a $b | Should -Be 'complex'
    }

    It "Uses git merge-base to classify - currentIsOlder" {
        Mock git { MockGitMergeBase @args }
        $a = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '3' }
        $b = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '2' }
        Get-ForkpointRelationship $a $b | Should -Be 'currentIsOlder'
    }

    It "Uses git merge-base to classify - currentIsNewer" {
        Mock git { MockGitMergeBase @args }
        $a = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '2' }
        $b = @{ forkpointType = 'git'; repoRoot = 'c:\foo\git'; commitId = '3' }
        Get-ForkpointRelationship $a $b | Should -Be 'currentIsNewer'
    }
}        
