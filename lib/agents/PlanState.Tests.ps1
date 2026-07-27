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
  state: ready-to-plan
---
# My Plan
"@

        $result = Get-PlanState $path

        @($result.Refined) | Should -HaveCount 0
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
        writeRaw $path "---`r`ncurrent-unit:`r`n  state: ready-to-plan`r`n---"

        (Get-PlanState $path).State | Should -Be 'ready-to-plan'
    }
}

Describe "Set-PlanState direct field updates" {
    It "writes a new file that doesn't exist yet" {
        $path = "$script:testDriveRoot/brand-new.md"

        Set-PlanState -PlanFile $path -State 'ready-to-plan' -First 'Step 1: alpha' | Out-Null

        $result = Get-PlanState $path
        $result.State    | Should -Be 'ready-to-plan'
        $result.First    | Should -Be 'Step 1: alpha'
    }

    It "defaults to LF line endings when writing a brand-new file" {
        $path = "$script:testDriveRoot/brand-new-lf.md"

        Set-PlanState -PlanFile $path -State 'ready-to-plan' | Out-Null

        (readRaw $path) | Should -Not -Match "`r`n"
        (readRaw $path) | Should -Match "`n"
    }

    It "handles content with no line-ending characters at all" {
        $path = "$script:testDriveRoot/no-newlines.md"
        writeRaw $path "# Title"

        Set-PlanState -PlanFile $path -State 'ready-to-plan' | Out-Null

        (Get-PlanState $path).State | Should -Be 'ready-to-plan'
    }

    It "creates a frontmatter block on a file that has none, preserving the body" {
        $path = "$script:testDriveRoot/create-fm.md"
        writeRaw $path "# My Plan`r`n`r`nbody text`r`n"

        Set-PlanState -PlanFile $path -State 'ready-to-plan' | Out-Null

        $result = Get-PlanState $path
        $result.State | Should -Be 'ready-to-plan'
        (readRaw $path) | Should -Match ([regex]::Escape("# My Plan`r`n`r`nbody text"))
    }

    It "updates only the specified field, leaving other frontmatter fields untouched" {
        $path = "$script:testDriveRoot/partial-update.md"
        writeRaw $path @"
---
current-unit:
  first: "Step 2: state script"
  last: "Step 2: state script"
  state: ready-to-plan
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

        Set-PlanState -PlanFile $path -State 'ready-to-plan' | Out-Null

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
  state: ready-to-plan
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

        Set-PlanState -PlanFile $path -State 'ready-to-plan' -First 'Step 1: alpha' | Out-Null

        $result = Get-PlanState $path
        $result.First | Should -Be 'Step 1: alpha'
        $result.Last  | Should -Be 'Step 1: alpha'
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

    It "sets state ready-to-plan when the target step is not in refined" {
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

        (Get-PlanState $path).State | Should -Be 'ready-to-plan'
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

    It "throws when the plan has no step headings" {
        $path = "$script:testDriveRoot/advance-no-headings.md"
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
        writeRaw $path "---`r`ncurrent-unit:`r`n  state: ready-to-plan`r`n---`r`n# Title`r`n"

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
  state: ready-to-plan
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
    It "writes state and first/last nested under current-unit" {
        $path = "$script:testDriveRoot/nested-write.md"
        writeRaw $path "# Plan`n"
        Set-PlanState -PlanFile $path -State 'ready-to-implement' -First 'Step 3: skills' | Out-Null
        $raw = readRaw $path
        $raw | Should -Match '(?m)^current-unit:'
        $raw | Should -Match '(?m)^  first: "Step 3: skills"'
        $raw | Should -Match '(?m)^  last: "Step 3: skills"'
        $raw | Should -Match '(?m)^  state: ready-to-implement'
        $raw | Should -Not -Match '(?m)^state:'
        $raw | Should -Not -Match '(?m)^first:'
    }

    It "round-trips state, first/last and refined through the nested schema" {
        $path = "$script:testDriveRoot/nested-roundtrip.md"
        writeRaw $path "# Plan`n"
        Set-PlanState -PlanFile $path -State 'ready-to-plan' -First 'Step 1: alpha' -Refined @('Step 2: beta') | Out-Null
        $r = Get-PlanState $path
        $r.State    | Should -Be 'ready-to-plan'
        $r.First    | Should -Be 'Step 1: alpha'
        $r.Last     | Should -Be 'Step 1: alpha'
        @($r.Refined) | Should -Be @('Step 2: beta')
    }
}
