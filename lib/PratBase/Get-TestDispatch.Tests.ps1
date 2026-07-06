BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe 'Get-TestDispatch' {
    BeforeAll {
        $root  = 'C:/test/repo'
        $subA  = "$root/lib/subA"
        $subB  = "$root/lib/subB"
        $targets = @(
            @{ id = 'subA'; root = $subA },
            @{ id = 'subB'; root = $subB }
        )
    }

    It 'focus = repo root: overlaps every target, Pester also runs' {
        $r = Get-TestDispatch $root $targets
        $r.RunPester | Should -BeTrue
        $r.Targets.Count | Should -Be 2
    }

    It 'focus = lib/ (ancestor of both targets): overlaps every target, Pester also runs' {
        $r = Get-TestDispatch "$root/lib" $targets
        $r.RunPester | Should -BeTrue
        $r.Targets.Count | Should -Be 2
    }

    It 'focus = a target dir exactly: only that target, Pester skipped' {
        $r = Get-TestDispatch $subA $targets
        $r.RunPester | Should -BeFalse
        $r.Targets.id | Should -Be @('subA')
    }

    It 'focus = a file inside a target: only that target, Pester skipped' {
        $r = Get-TestDispatch "$subA/test_foo.py" $targets
        $r.RunPester | Should -BeFalse
        $r.Targets.id | Should -Be @('subA')
    }

    It 'focus = the other target dir: only that one, Pester skipped' {
        $r = Get-TestDispatch $subB $targets
        $r.RunPester | Should -BeFalse
        $r.Targets.id | Should -Be @('subB')
    }

    It 'focus = unrelated dir: no targets overlap, Pester runs' {
        $r = Get-TestDispatch "$root/lib/deu" $targets
        $r.RunPester | Should -BeTrue
        $r.Targets.Count | Should -Be 0
    }

    It 'no sub-targets at all: Pester always runs' {
        $r = Get-TestDispatch $root @()
        $r.RunPester | Should -BeTrue
        $r.Targets.Count | Should -Be 0
    }
}
