BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    $mockedGit = {
        if ($args[2] -eq 'merge-base') {
            return '1234'
        }
        if ($args[2] -eq 'log') {
            return '2023-10-01T12:00:00+00:00'
        }
        throw "Unexpected git command: $args"
    }

    $mockedGitForkpointReturnsNull = {
        if ($args[2] -eq 'merge-base') {
            if ($args[3] -eq '--fork-point') {
                return $null
            }
            return '1234'
        }
        if ($args[2] -eq 'log') {
            return '2023-10-01T12:00:00+00:00'
        }
        throw "Unexpected git command: $args"
    }
}

Describe "Get-CurrentGitForkpoint" {
    It "Should return a forkpoint" {
        Mock git $mockedGit

        $repoRoot = "c:\foo\git"
        $forkpoint = Get-CurrentGitForkpoint $repoRoot
        $forkpoint.forkpointType | Should -Be 'git'
        $forkpoint.commitId | Should -Be '1234'
        $forkpoint.repoRoot | Should -Be $repoRoot
        $forkpoint.authorDate | Should -BeOfType [datetime]
    }
    It "Handles detached-head state" {
        Mock git $mockedGitForkpointReturnsNull

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
}        
