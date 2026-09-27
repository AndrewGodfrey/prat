BeforeDiscovery {
    . "$PSScriptRoot/PlanState.ps1"
}

BeforeAll {
    Import-Module "$PSScriptRoot/../PratBase/PratBase.psd1" -Force
    . "$PSScriptRoot/PlanState.ps1"
    $script:testDriveRoot = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')

    function writeRaw([string] $path, [string] $content) {
        [System.IO.File]::WriteAllText($path, $content)
    }

    function readRaw([string] $path) {
        return [System.IO.File]::ReadAllText($path)
    }
}

Describe "Get-PlanState" {
    It "returns nulls and empty refined when file has no frontmatter" {
        $path = "$script:testDriveRoot/no-fm.md"
        writeRaw $path "# My Plan`r`n`r`nsome body`r`n"

        $result = Get-PlanState $path

        $result.State    | Should -BeNullOrEmpty
        $result.First    | Should -BeNullOrEmpty
        $result.Last     | Should -BeNullOrEmpty
        @($result.Refined) | Should -HaveCount 0
    }

    It "parses state, unit extent, and refined from existing frontmatter" {
        $path = "$script:testDriveRoot/with-fm.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 3: skills"
  last: "Step 3: skills"
  state: ready-to-implement
refined:
  - "Step 4: launcher"
  - "Step 5: docs"
---
# My Plan
"@

        $result = Get-PlanState $path

        $result.State    | Should -Be 'ready-to-implement'
        $result.First    | Should -Be 'Step 3: skills'
        $result.Last     | Should -Be 'Step 3: skills'
        @($result.Refined) | Should -Be @('Step 4: launcher', 'Step 5: docs')
    }

    It "parses a multi-step unit whose first and last differ" {
        $path = "$script:testDriveRoot/with-range.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 3: gamma"
  state: ready-for-user-review
---
# My Plan
"@

        $result = Get-PlanState $path

        $result.First | Should -Be 'Step 1: alpha'
        $result.Last  | Should -Be 'Step 3: gamma'
        $result.State | Should -Be 'ready-for-user-review'
    }

    It "returns empty refined array when the key is absent" {
        $path = "$script:testDriveRoot/no-refined.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 2: state script"
  last: "Step 2: state script"
  state: ready-to-refine
---
# My Plan
"@

        $result = Get-PlanState $path

        @($result.Refined) | Should -HaveCount 0
    }

    It "reports HasSteps true when the body carries a step heading" {
        $path = "$script:testDriveRoot/has-steps.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  state: ready-to-refine
---
# My Plan

### Step 1: alpha
"@

        (Get-PlanState $path).HasSteps | Should -BeTrue
    }

    It "reports StepHeadings as the body's Step headings, in order, excluding non-Step headings" {
        $path = "$script:testDriveRoot/step-headings.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  state: ready-to-implement
---
# My Plan

## Background

### Step 1: alpha

## Step 2: beta

### Step 3: gamma
"@

        @(Get-PlanState $path).StepHeadings | Should -Be @('Step 1: alpha','Step 2: beta','Step 3: gamma')
    }

    It "reports HasSteps false for a plan whose body has no step heading" {
        $path = "$script:testDriveRoot/no-steps.md"
        writeRaw $path @"
---
current-unit:
  state: ready-to-refine
---
# My Plan

## Background
"@

        (Get-PlanState $path).HasSteps | Should -BeFalse
    }

    It "reports HasSteps false for a skeleton with neither frontmatter nor steps" {
        $path = "$script:testDriveRoot/skeleton.md"
        writeRaw $path "# My Plan`r`n`r`nsome notes`r`n"

        (Get-PlanState $path).HasSteps | Should -BeFalse
    }

    It "reports HasSteps false for a file that does not exist" {
        (Get-PlanState "$script:testDriveRoot/nope.md").HasSteps | Should -BeFalse
    }
}

Describe "Get-PlanState tilde paths" {
    It "expands a leading '~' before resolving (raw File I/O cannot read a literal '~')" {
        # ~ only expands relative to $HOME, so the plan file must live under $HOME for this to
        # exercise the tilde path. Created and cleaned up here rather than in TestDrive.
        $tildeDirName = "planStateTest_$([guid]::NewGuid().ToString('N'))"
        $realTildeDir = Join-Path $HOME $tildeDirName
        try {
            New-Item -ItemType Directory $realTildeDir | Out-Null
            $path = "$realTildeDir/plan.md"
            writeRaw $path @"
---
current-unit:
  first: "Step 1: tilde test"
  last: "Step 1: tilde test"
  state: ready-to-implement
---
# My Plan
"@

            $result = Get-PlanState "~/$tildeDirName/plan.md"

            $result.State | Should -Be 'ready-to-implement'
        } finally {
            Remove-Item $realTildeDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Get-PlanState edge cases" {
    It "returns nulls when the file does not exist" {
        $result = Get-PlanState "$script:testDriveRoot/does-not-exist.md"

        $result.State    | Should -BeNullOrEmpty
        $result.First    | Should -BeNullOrEmpty
        @($result.Refined) | Should -HaveCount 0
    }

    It "handles an empty frontmatter block with no keys" {
        $path = "$script:testDriveRoot/empty-fm.md"
        writeRaw $path "---`r`n---`r`n# Title`r`n"

        $result = Get-PlanState $path

        $result.State    | Should -BeNullOrEmpty
        $result.First    | Should -BeNullOrEmpty
    }

    It "handles a frontmatter block with no body after it" {
        $path = "$script:testDriveRoot/no-body.md"
        writeRaw $path "---`r`ncurrent-unit:`r`n  state: ready-to-refine`r`n---"

        (Get-PlanState $path).State | Should -Be 'ready-to-refine'
    }
}

Describe "Set-PlanState direct field updates" {
    It "writes a new file that doesn't exist yet" {
        $path = "$script:testDriveRoot/brand-new.md"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' -First 'Step 1: alpha' | Out-Null

        $result = Get-PlanState $path
        $result.State    | Should -Be 'ready-to-refine'
        $result.First    | Should -Be 'Step 1: alpha'
    }

    It "defaults to LF line endings when writing a brand-new file" {
        $path = "$script:testDriveRoot/brand-new-lf.md"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' | Out-Null

        (readRaw $path) | Should -Not -Match "`r`n"
        (readRaw $path) | Should -Match "`n"
    }

    It "handles content with no line-ending characters at all" {
        $path = "$script:testDriveRoot/no-newlines.md"
        writeRaw $path "# Title"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' | Out-Null

        (Get-PlanState $path).State | Should -Be 'ready-to-refine'
    }

    It "creates a frontmatter block on a file that has none, preserving the body" {
        $path = "$script:testDriveRoot/create-fm.md"
        writeRaw $path "# My Plan`r`n`r`nbody text`r`n"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' | Out-Null

        $result = Get-PlanState $path
        $result.State | Should -Be 'ready-to-refine'
        (readRaw $path) | Should -Match ([regex]::Escape("# My Plan`r`n`r`nbody text"))
    }

    It "updates only the specified field, leaving other frontmatter fields untouched" {
        $path = "$script:testDriveRoot/partial-update.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 2: state script"
  last: "Step 2: state script"
  state: ready-to-refine
---
# My Plan
"@

        Set-PlanState -PlanFile $path -State 'ready-for-user-review' | Out-Null

        $result = Get-PlanState $path
        $result.State    | Should -Be 'ready-for-user-review'
        $result.First    | Should -Be 'Step 2: state script'
    }

    It "preserves an existing multi-step range when only -State changes" {
        $path = "$script:testDriveRoot/partial-update-range.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 3: gamma"
  state: ready-to-implement
---
# My Plan
"@

        Set-PlanState -PlanFile $path -State 'ready-for-user-review' | Out-Null

        $result = Get-PlanState $path
        $result.State | Should -Be 'ready-for-user-review'
        $result.First | Should -Be 'Step 1: alpha'
        $result.Last  | Should -Be 'Step 3: gamma'
    }

    It "preserves an existing file's CRLF line endings" {
        $path = "$script:testDriveRoot/crlf.md"
        writeRaw $path "# Title`r`n`r`nbody`r`n"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' | Out-Null

        (readRaw $path) | Should -Match "`r`n"
        (readRaw $path) | Should -Not -Match "(?<!\r)\n"
    }

    It "round-trips a first value containing a colon" {
        $path = "$script:testDriveRoot/colon-value.md"
        writeRaw $path "# Title`r`n"

        Set-PlanState -PlanFile $path -First 'Step 3: skills' | Out-Null

        (Get-PlanState $path).First | Should -Be 'Step 3: skills'
    }

    It "replaces the refined list wholesale when -Refined is passed" {
        $path = "$script:testDriveRoot/replace-refined.md"
        writeRaw $path @"
---
current-unit:
  state: ready-to-refine
refined:
  - "Step 4: launcher"
---
# Title
"@

        Set-PlanState -PlanFile $path -Refined @('Step 5: docs') | Out-Null

        @((Get-PlanState $path).Refined) | Should -Be @('Step 5: docs')
    }
}

Describe "current-unit unit-of-1 backward compat" {
    It "fills -last from -first when only -First is written (single-step unit, same shape as before the rename)" {
        $path = "$script:testDriveRoot/unit-of-1.md"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' -First 'Step 1: alpha' | Out-Null

        $result = Get-PlanState $path
        $result.First | Should -Be 'Step 1: alpha'
        $result.Last  | Should -Be 'Step 1: alpha'
    }

    It "moves last with -First, so that renaming a step's heading doesn't batch the unit" {
        $path = "$script:testDriveRoot/unit-of-1-repoint.md"
        Set-PlanState -PlanFile $path -State 'ready-to-refine' -First 'Step 8: the loop' | Out-Null

        Set-PlanState -PlanFile $path -First 'Step 8: headless mode' | Out-Null

        $result = Get-PlanState $path
        $result.First | Should -Be 'Step 8: headless mode'
        $result.Last  | Should -Be 'Step 8: headless mode'
        readRaw $path | Should -Not -Match 'last:'
    }

    It "refuses to re-point a batched unit by -First alone" {
        # Under-specified: collapsing the unit to one step loses a hand-declared extent, and keeping
        # the old `last` is what a renumber would make stale. The caller says which.
        $path = "$script:testDriveRoot/unit-of-2-repoint.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 3: skills"
  state: ready-to-implement
---
# Plan
"@

        { Set-PlanState -PlanFile $path -First 'Step 2: beta' } | Should -Throw -ExpectedMessage '*-Last*'

        (Get-PlanState $path).First | Should -Be 'Step 1: alpha'
    }

    It "re-points a batched unit when both ends are given" {
        $path = "$script:testDriveRoot/unit-of-2-both.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 3: skills"
  state: ready-to-implement
---
# Plan
"@

        Set-PlanState -PlanFile $path -First 'Step 2: beta' -Last 'Step 4: docs' | Out-Null

        $result = Get-PlanState $path
        $result.First | Should -Be 'Step 2: beta'
        $result.Last  | Should -Be 'Step 4: docs'
    }

    It "refuses -Last without -First" {
        $path = "$script:testDriveRoot/last-alone.md"
        Set-PlanState -PlanFile $path -State 'ready-to-refine' -First 'Step 1: alpha' | Out-Null

        { Set-PlanState -PlanFile $path -Last 'Step 3: skills' } | Should -Throw -ExpectedMessage '*-First*'

        (Get-PlanState $path).Last | Should -Be 'Step 1: alpha'
    }

    It "refuses -First or -Last alongside -Advance, which names its target with -ToStep" {
        $path = "$script:testDriveRoot/advance-with-first.md"
        writeRaw $path @"
# Plan

## Step 1: alpha
## Step 2: beta
"@

        { Set-PlanState -PlanFile $path -Advance -First 'Step 2: beta' } | Should -Throw -ExpectedMessage '*-ToStep*'
    }
}

Describe "Set-PlanState -Advance" {
    It "picks the first step heading when there is no current unit" {
        $path = "$script:testDriveRoot/advance-first.md"
        writeRaw $path @"
# Plan

## Step 1: alpha
## Step 2: beta
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        (Get-PlanState $path).First | Should -Be 'Step 1: alpha'
    }

    It "picks the only step heading when the plan has exactly one" {
        $path = "$script:testDriveRoot/advance-single.md"
        writeRaw $path @"
# Plan

## Step 1: alpha
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        (Get-PlanState $path).First | Should -Be 'Step 1: alpha'
    }

    It "advances to the heading after the current unit's last step" {
        $path = "$script:testDriveRoot/advance-next.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
  state: ready-for-user-review
---
# Plan

## Step 1: alpha
## Step 2: beta
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        $result = Get-PlanState $path
        $result.First | Should -Be 'Step 2: beta'
        $result.Last  | Should -Be 'Step 2: beta'
    }

    It "advances past a multi-step unit's last step, resetting the extent to a single step" {
        $path = "$script:testDriveRoot/advance-multi.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 2: beta"
  state: ready-for-user-review
---
# Plan

## Step 1: alpha
## Step 2: beta
## Step 3: gamma
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        $result = Get-PlanState $path
        $result.First | Should -Be 'Step 3: gamma'
        $result.Last  | Should -Be 'Step 3: gamma'
    }

    It "matches step headings at varying heading levels" {
        $path = "$script:testDriveRoot/advance-levels.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
---
# Plan

## Step 1: alpha
### Step 2: beta
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        (Get-PlanState $path).First | Should -Be 'Step 2: beta'
    }

    It "honors -ToStep to jump to an explicit step, out of document order" {
        $path = "$script:testDriveRoot/advance-tostep.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
---
# Plan

## Step 1: alpha
## Step 2: beta
## Step 3: gamma
"@

        Set-PlanState -PlanFile $path -Advance -ToStep 'Step 3' | Out-Null

        (Get-PlanState $path).First | Should -Be 'Step 3: gamma'
    }

    It "pops the matching entry from refined and sets state ready-to-implement" {
        $path = "$script:testDriveRoot/advance-pop-refined.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
refined:
  - "Step 2: beta"
  - "Step 3: gamma"
---
# Plan

## Step 1: alpha
## Step 2: beta
## Step 3: gamma
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        $result = Get-PlanState $path
        $result.State | Should -Be 'ready-to-implement'
        $result.First | Should -Be 'Step 2: beta'
        $result.Last  | Should -Be 'Step 2: beta'
        @($result.Refined) | Should -Be @('Step 3: gamma')
    }

    It "sets state ready-to-refine when the target step is not in refined" {
        $path = "$script:testDriveRoot/advance-not-refined.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
---
# Plan

## Step 1: alpha
## Step 2: beta
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        (Get-PlanState $path).State | Should -Be 'ready-to-refine'
    }

    It "lands on the first remaining step when the current unit's steps have been moved out" {
        # This is what /wrap does on every close: the unit's steps are cut to the done file before
        # the pointer is advanced, so the pointer naming no heading is the normal case.
        $path = "$script:testDriveRoot/advance-unit-moved-out.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 2: done and gone"
  last: "Step 3: also gone"
  state: ready-for-user-review
---
# Plan

## Step 4: next up
## Step 5: after that
"@

        Set-PlanState -PlanFile $path -Advance | Out-Null

        (Get-PlanState $path).First | Should -Be 'Step 4: next up'
    }

    It "throws when the current unit's last step is the last step" {
        $path = "$script:testDriveRoot/advance-last.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 2: beta"
  last: "Step 2: beta"
---
# Plan

## Step 1: alpha
## Step 2: beta
"@

        { Set-PlanState -PlanFile $path -Advance } | Should -Throw
    }

    It "lands the plan at ready-for-user-review when the last step has left and no headings remain" {
        # /wrap on the final step: its body is cut to the done file before the pointer is advanced,
        # so the pointer names a step that is no longer in the file. The pointer's step is what the
        # user reviews (the branch), so the landing state is the one a normal close would leave.
        $path = "$script:testDriveRoot/advance-no-headings.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 3: final"
  last: "Step 3: final"
  state: ready-for-user-review
---
# Plan

no steps here
"@

        $result = Set-PlanState -PlanFile $path -Advance

        $result.State   | Should -Be 'ready-for-user-review'
        $result.First   | Should -Be 'Step 3: final'
        $result.Last    | Should -Be 'Step 3: final'
        $result.HasSteps | Should -BeFalse
    }

    It "throws when the plan has no step headings and no pointer either — that one is a misuse" {
        $path = "$script:testDriveRoot/advance-no-headings-no-pointer.md"
        writeRaw $path "# Plan`r`n`r`nno steps here`r`n"

        { Set-PlanState -PlanFile $path -Advance } | Should -Throw
    }

    It "throws when -ToStep does not match any heading" {
        $path = "$script:testDriveRoot/advance-tostep-missing.md"
        writeRaw $path @"
# Plan

## Step 1: alpha
"@

        { Set-PlanState -PlanFile $path -Advance -ToStep 'Step 9' } | Should -Throw
    }
}

Describe "Get-PlanStepId" {
    It "extracts the leading 'Step N' token, case-insensitively and whitespace-normalized" {
        Get-PlanStepId 'Step 3: skills'   | Should -Be (Get-PlanStepId 'step   3')
    }

    It "treats a raw label without a Step prefix as its own id" {
        Get-PlanStepId 'gamma' | Should -Be (Get-PlanStepId 'GAMMA')
    }
}

Describe "Get-PlanState HasFrontmatter" {
    It "is false when the file has no frontmatter block" {
        $path = "$script:testDriveRoot/hasfm-none.md"
        writeRaw $path "# My Plan`r`n`r`nbody`r`n"

        (Get-PlanState $path).HasFrontmatter | Should -Be $false
    }

    It "is false when the file does not exist" {
        (Get-PlanState "$script:testDriveRoot/hasfm-missing.md").HasFrontmatter | Should -Be $false
    }

    It "is true for an empty frontmatter block with no keys" {
        $path = "$script:testDriveRoot/hasfm-empty.md"
        writeRaw $path "---`r`n---`r`n# Title`r`n"

        (Get-PlanState $path).HasFrontmatter | Should -Be $true
    }

    It "is true when frontmatter carries state" {
        $path = "$script:testDriveRoot/hasfm-state.md"
        writeRaw $path "---`r`ncurrent-unit:`r`n  state: ready-to-refine`r`n---`r`n# Title`r`n"

        (Get-PlanState $path).HasFrontmatter | Should -Be $true
    }
}

Describe "current-step backward compatibility (pre-rename single-pointer shape)" {
    It "Get-PlanState parses an old current-step block into First/Last/State" {
        $path = "$script:testDriveRoot/old-shape.md"
        writeRaw $path @"
---
current-step:
  name: "Step 3: skills"
  state: ready-to-implement
---
# My Plan
"@

        $result = Get-PlanState $path

        $result.State | Should -Be 'ready-to-implement'
        $result.First | Should -Be 'Step 3: skills'
        $result.Last  | Should -Be 'Step 3: skills'
    }

    It "Set-PlanState migrates an old current-step block to current-unit on next write" {
        $path = "$script:testDriveRoot/old-shape-migrate.md"
        writeRaw $path @"
---
current-step:
  name: "Step 3: skills"
  state: ready-to-implement
---
# My Plan
"@

        Set-PlanState -PlanFile $path | Out-Null

        $raw = readRaw $path
        $raw | Should -Match '(?m)^current-unit:'
        $raw | Should -Not -Match '(?m)^current-step:'
        $result = Get-PlanState $path
        $result.State | Should -Be 'ready-to-implement'
        $result.First | Should -Be 'Step 3: skills'
        $result.Last  | Should -Be 'Step 3: skills'
    }

    It "preserves a refined list alongside an old current-step block when migrating" {
        $path = "$script:testDriveRoot/old-shape-refined.md"
        writeRaw $path @"
---
current-step:
  name: "Step 1: alpha"
  state: ready-to-refine
refined:
  - "Step 2: beta"
---
# My Plan
"@

        Set-PlanState -PlanFile $path | Out-Null

        $result = Get-PlanState $path
        $result.First | Should -Be 'Step 1: alpha'
        @($result.Refined) | Should -Be @('Step 2: beta')
    }
}

Describe "current-unit nested schema" {
    It "writes state and first nested under current-unit" {
        $path = "$script:testDriveRoot/nested-write.md"
        writeRaw $path "# Plan`n"
        Set-PlanState -PlanFile $path -State 'ready-to-implement' -First 'Step 3: skills' | Out-Null
        $raw = readRaw $path
        $raw | Should -Match '(?m)^current-unit:'
        $raw | Should -Match '(?m)^  first: "Step 3: skills"'
        $raw | Should -Match '(?m)^  state: ready-to-implement'
        $raw | Should -Not -Match '(?m)^state:'
        $raw | Should -Not -Match '(?m)^first:'
    }

    It "omits last on a one-step unit, and the reader fills it back in" {
        $path = "$script:testDriveRoot/nested-last-omitted.md"
        writeRaw $path "# Plan`n"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' -First 'Step 3: skills' | Out-Null

        (readRaw $path) | Should -Not -Match '(?m)^  last:'
        (Get-PlanState $path).Last | Should -Be 'Step 3: skills'
    }

    It "keeps last on a multi-step unit" {
        $path = "$script:testDriveRoot/nested-last-kept.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  last: `"Step 3: gamma`"`n---`n# Plan`n"

        Set-PlanState -PlanFile $path -State 'ready-to-implement' | Out-Null

        (readRaw $path) | Should -Match '(?m)^  last: "Step 3: gamma"'
    }

    It "round-trips state, first/last and refined through the nested schema" {
        $path = "$script:testDriveRoot/nested-roundtrip.md"
        writeRaw $path "# Plan`n"
        Set-PlanState -PlanFile $path -State 'ready-to-refine' -First 'Step 1: alpha' -Refined @('Step 2: beta') | Out-Null
        $r = Get-PlanState $path
        $r.State    | Should -Be 'ready-to-refine'
        $r.First    | Should -Be 'Step 1: alpha'
        $r.Last     | Should -Be 'Step 1: alpha'
        @($r.Refined) | Should -Be @('Step 2: beta')
    }

    It "fills in first from a hand-written unit that declares only last" {
        # The pair's invariant, from the other side: a file carrying only the other half is a shape
        # the reader can still meet.
        $path = "$script:testDriveRoot/nested-last-only.md"
        writeRaw $path "---`ncurrent-unit:`n  last: `"Step 1: alpha`"`n  state: ready-to-refine`n---`n# Plan`n"

        Set-PlanState -PlanFile $path -State 'ready-to-implement' | Out-Null

        $r = Get-PlanState $path
        $r.First | Should -Be 'Step 1: alpha'
        $r.Last  | Should -Be 'Step 1: alpha'
    }

    It "fills the pair on read, without a write first — -Advance looks the current step up by last" {
        $path = "$script:testDriveRoot/nested-fill-on-read.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  state: ready-to-refine`n---`n# Plan`n"

        (Get-PlanState $path).Last | Should -Be 'Step 1: alpha'
    }
}

Describe "commit-grant" {
    It "reads the branch and repos a plan declares" {
        $path = "$script:testDriveRoot/grant.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
  state: ready-to-implement
commit-grant:
  branch: "myFeature"
  repos: [foo, prat]
---
# My Plan
"@

        $result = Get-PlanState $path

        $result.CommitBranch | Should -Be 'myFeature'
        @($result.CommitRepos) | Should -Be @('foo', 'prat')
    }

    It "reads a flow list whose entries are quoted or padded" {
        $path = "$script:testDriveRoot/grant-quoted.md"
        writeRaw $path @"
---
commit-grant:
  branch: "myFeature"
  repos: [ "foo" , "c:/src/myrepo" ]
---
# My Plan
"@

        @(Get-PlanState $path).CommitRepos | Should -Be @('foo', 'c:/src/myrepo')
    }

    It "reports no grant when the plan declares none" {
        $path = "$script:testDriveRoot/no-grant.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  state: ready-to-refine`n---`n# Plan`n"

        $result = Get-PlanState $path

        $result.CommitBranch | Should -BeNullOrEmpty
        @($result.CommitRepos) | Should -HaveCount 0
    }

    It "keeps a hand-written grant when the lifecycle fields are rewritten" {
        # The write side rebuilds the whole frontmatter block from what the read side parsed, so an
        # unparsed key would be deleted by any Set-PlanState call.
        $path = "$script:testDriveRoot/grant-preserved.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
  state: ready-to-refine
commit-grant:
  branch: "myFeature"
  repos: [foo, prat]
---
# My Plan

## Step 1: alpha
"@

        Set-PlanState -PlanFile $path -State 'ready-to-implement' | Out-Null

        $result = Get-PlanState $path
        $result.State        | Should -Be 'ready-to-implement'
        $result.CommitBranch | Should -Be 'myFeature'
        @($result.CommitRepos) | Should -Be @('foo', 'prat')
        (readRaw $path) | Should -Match '(?m)^  repos: \[foo, prat\]'
    }

    It "keeps a branch declared with no repos" {
        $path = "$script:testDriveRoot/grant-branch-only.md"
        writeRaw $path "---`ncommit-grant:`n  branch: `"myFeature`"`n---`n# Plan`n"

        Set-PlanState -PlanFile $path -State 'ready-to-refine' | Out-Null

        $result = Get-PlanState $path
        $result.CommitBranch | Should -Be 'myFeature'
        @($result.CommitRepos) | Should -HaveCount 0
    }

    It "writes a branch and repos via -CommitBranch/-CommitRepos" {
        $path = "$script:testDriveRoot/grant-write.md"
        writeRaw $path "# Plan`n"

        Set-PlanState -PlanFile $path -CommitBranch 'myFeature' -CommitRepos @('foo', 'prat') | Out-Null

        $result = Get-PlanState $path
        $result.CommitBranch   | Should -Be 'myFeature'
        @($result.CommitRepos) | Should -Be @('foo', 'prat')
    }

    It "writes a branch with no repos via -CommitBranch alone" {
        $path = "$script:testDriveRoot/grant-write-branch-only.md"
        writeRaw $path "# Plan`n"

        Set-PlanState -PlanFile $path -CommitBranch 'myFeature' | Out-Null

        $result = Get-PlanState $path
        $result.CommitBranch   | Should -Be 'myFeature'
        @($result.CommitRepos) | Should -HaveCount 0
    }

    It "overwrites a previously declared grant via -CommitBranch/-CommitRepos" {
        $path = "$script:testDriveRoot/grant-overwrite.md"
        writeRaw $path "---`ncommit-grant:`n  branch: `"old`"`n  repos: [foo]`n---`n# Plan`n"

        Set-PlanState -PlanFile $path -CommitBranch 'new' -CommitRepos @('prat') | Out-Null

        $result = Get-PlanState $path
        $result.CommitBranch   | Should -Be 'new'
        @($result.CommitRepos) | Should -Be @('prat')
    }
}

Describe "automatable" {
    It "reads a star value" {
        $path = "$script:testDriveRoot/auto-star.md"
        writeRaw $path "---`nworkflow: branch-review`nautomatable: *`n---`n# Plan`n"

        (Get-PlanState $path).Automatable | Should -Be '*'
    }

    It "reads a range value" {
        $path = "$script:testDriveRoot/auto-range.md"
        writeRaw $path "---`nautomatable: 16-19`n---`n# Plan`n"

        (Get-PlanState $path).Automatable | Should -Be '16-19'
    }

    It "reads a list value" {
        $path = "$script:testDriveRoot/auto-list.md"
        writeRaw $path "---`nautomatable: 16, 19`n---`n# Plan`n"

        (Get-PlanState $path).Automatable | Should -Be '16, 19'
    }

    It "reads a mixed range-and-number value" {
        $path = "$script:testDriveRoot/auto-mixed.md"
        writeRaw $path "---`nautomatable: 16-19, 21`n---`n# Plan`n"

        (Get-PlanState $path).Automatable | Should -Be '16-19, 21'
    }

    It "reports null when the plan declares no automatable field" {
        $path = "$script:testDriveRoot/auto-absent.md"
        writeRaw $path "---`nworkflow: branch-review`n---`n# Plan`n"

        (Get-PlanState $path).Automatable | Should -BeNullOrEmpty
    }

    It "throws on a non-numeric token" {
        $path = "$script:testDriveRoot/auto-bad1.md"
        writeRaw $path "---`nautomatable: abc`n---`n# Plan`n"

        { Get-PlanState $path } | Should -Throw '*automatable*'
    }

    It "throws on an empty value" {
        $path = "$script:testDriveRoot/auto-bad-empty.md"
        writeRaw $path "---`nautomatable:`n---`n# Plan`n"

        { Get-PlanState $path } | Should -Throw '*automatable*'
    }

    It "throws on an inverted range" {
        $path = "$script:testDriveRoot/auto-bad2.md"
        writeRaw $path "---`nautomatable: 19-16`n---`n# Plan`n"

        { Get-PlanState $path } | Should -Throw '*automatable*'
    }

    It "throws on a star mixed with numbers" {
        $path = "$script:testDriveRoot/auto-bad3.md"
        writeRaw $path "---`nautomatable: *, 16`n---`n# Plan`n"

        { Get-PlanState $path } | Should -Throw '*automatable*'
    }

    It "keeps a hand-written automatable value when the lifecycle fields are rewritten" {
        $path = "$script:testDriveRoot/auto-preserved.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
  state: ready-to-refine
workflow: branch-review
automatable: 16-19
commit-grant:
  branch: "myFeature"
  repos: [foo, prat]
---
# My Plan

## Step 1: alpha
"@

        Set-PlanState -PlanFile $path -State 'ready-to-implement' | Out-Null

        $result = Get-PlanState $path
        $result.State       | Should -Be 'ready-to-implement'
        $result.Automatable | Should -Be '16-19'
        (readRaw $path) | Should -Match '(?m)^automatable: 16-19'
    }
}

Describe "workflow" {
    It "reads the mode a plan declares" {
        $path = "$script:testDriveRoot/workflow.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
  state: ready-to-implement
workflow: branch-review
---
# My Plan
"@

        (Get-PlanState $path).Workflow | Should -Be 'branch-review'
    }

    It "reports no mode when the plan declares none" {
        # Absence is the tick-tock case: consumers test for the modes that loosen what a session may
        # do, so a plan that says nothing gets the strictest one.
        $path = "$script:testDriveRoot/workflow-absent.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  state: ready-to-refine`n---`n# Plan`n"

        (Get-PlanState $path).Workflow | Should -BeNullOrEmpty
    }

    It "keeps a declared mode when the lifecycle fields are rewritten" {
        $path = "$script:testDriveRoot/workflow-preserved.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 1: alpha"
  last: "Step 1: alpha"
  state: ready-to-refine
workflow: step-review
commit-grant:
  branch: "myFeature"
  repos: [foo, prat]
---
# My Plan

## Step 1: alpha
"@

        Set-PlanState -PlanFile $path -State 'ready-to-implement' | Out-Null

        $result = Get-PlanState $path
        $result.State    | Should -Be 'ready-to-implement'
        $result.Workflow | Should -Be 'step-review'
        (readRaw $path) | Should -Match '(?m)^  state: ready-to-implement\r?\nworkflow: step-review\r?\ncommit-grant:'
    }

    It "reads a mode from a plan with no current-unit block" {
        $path = "$script:testDriveRoot/workflow-only.md"
        writeRaw $path "---`nworkflow: tick-tock`n---`n# Plan`n"

        (Get-PlanState $path).Workflow | Should -Be 'tick-tock'
    }

    It "writes a mode via -Workflow" {
        $path = "$script:testDriveRoot/workflow-write.md"
        writeRaw $path "# Plan`n"

        Set-PlanState -PlanFile $path -Workflow 'branch-review' | Out-Null

        (Get-PlanState $path).Workflow | Should -Be 'branch-review'
    }

    It "overwrites a previously declared mode via -Workflow" {
        $path = "$script:testDriveRoot/workflow-overwrite.md"
        writeRaw $path "---`nworkflow: tick-tock`n---`n# Plan`n"

        Set-PlanState -PlanFile $path -Workflow 'step-review' | Out-Null

        (Get-PlanState $path).Workflow | Should -Be 'step-review'
    }
}

Describe "legacy state spellings" {
    It "reads ready-to-plan as ready-to-refine" {
        $path = "$script:testDriveRoot/legacy-rtp.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  state: ready-to-plan`n---`n# Plan`n"

        (Get-PlanState $path).State | Should -Be 'ready-to-refine'
    }

    It "migrates ready-to-plan in the file on the next write" {
        $path = "$script:testDriveRoot/legacy-rtp-migrate.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  state: ready-to-plan`n---`n# Plan`n"

        Set-PlanState -PlanFile $path | Out-Null

        (readRaw $path) | Should -Match '(?m)^  state: ready-to-refine'
    }

    It "canonicalizes a legacy value passed to -State, so no caller can write it back" {
        $path = "$script:testDriveRoot/legacy-rtp-setter.md"
        writeRaw $path "# Plan`n"

        Set-PlanState -PlanFile $path -State 'ready-to-plan' | Out-Null

        (readRaw $path) | Should -Match '(?m)^  state: ready-to-refine'
    }

    It "reads checkpointed as ready-to-implement (legacy state)" {
        $path = "$script:testDriveRoot/legacy-ckpt.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  state: checkpointed`n---`n# Plan`n"

        $result = Get-PlanState $path

        $result.State | Should -Be 'ready-to-implement'
    }

    It "migrates a checkpointed state on the next write" {
        $path = "$script:testDriveRoot/legacy-ckpt-migrate.md"
        writeRaw $path "---`ncurrent-unit:`n  first: `"Step 1: alpha`"`n  state: checkpointed`n---`n# Plan`n"

        Set-PlanState -PlanFile $path | Out-Null

        $raw = readRaw $path
        $raw | Should -Match '(?m)^  state: ready-to-implement'
        $raw | Should -Not -Match 'checkpointed'
    }
}
