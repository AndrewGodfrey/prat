using module ..\TextFileEditor\TextFileEditor.psd1
using module ..\PratBase\PratBase.psd1

# PlanState.ps1
# CRLF-safe create/read/update for the plan-lifecycle frontmatter: current-unit (a contiguous run
# of one or more steps, `first`/`last`, plus `state`) and `refined`. The model never
# hand-edits these — only this script writes them.
#
# `workflow` (which of the three ways of working a plan runs in), `commit-grant` (branch plus repos)
# and `automatable` (which steps an unattended run may work) are declared by hand, not inferred:
# `-Workflow`/`-CommitBranch`/`-CommitRepos` let a caller declare the first two, and all three
# round-trip untouched through every other call, since the write side rebuilds the whole block from
# what the read side parsed.
#
# A "unit" is the pointer's granularity: `first == last` is the common single-step case; `first !=
# last` is a batched multi-step unit — the pointer stays fixed at the unit's extent through
# implementation and review, and `-Advance` moves past `last` to the next single-step unit. The
# batch exists so that one review can cover several steps: the agent walks the pointer through the
# unit's interior steps itself, and only the user closes the unit. `last` is written down only when
# it differs from `first`; the read side fills the pair back in either way. A batch is declared by
# hand; `-First` re-points a single-step unit on its own, and needs `-Last` with it to move a
# batched one, since neither end can be inferred from the other.
#
# `state` is the unit's phase and nothing else (see ConvertTo-CanonicalPlanState for the values).
#
# Read side also accepts the pre-rename `current-step: { name, state }` shape and the pre-rename
# state spellings, for plans not yet migrated (e.g. on a machine where this file hasn't landed yet).
# Write side always emits the current shape - so any Set-PlanState call on such a file migrates it,
# even a no-op call (`Set-PlanState -PlanFile <path>`) made solely to force the rewrite.
#
# Line-ending detection/preservation and range-based splicing are delegated to TextFileEditor's
# LineArray class; this file only owns the YAML shape and the unit-pointer/advance logic.

function ConvertFrom-PlanYamlScalar([string] $raw) {
    $v = $raw.Trim()
    if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
        $v = $v.Substring(1, $v.Length - 2) -replace '\\"', '"'
    }
    return $v
}

function ConvertTo-PlanYamlScalar([string] $value) {
    $escaped = $value -replace '"', '\"'
    return "`"$escaped`""
}

# A YAML flow sequence (`[de, prat]`) as a string array. Flow rather than a block list so the whole
# value stays on one line and the nested-block reader below needs no list handling.
function ConvertFrom-PlanYamlFlowList([string] $raw) {
    $v = $raw.Trim()
    if ($v.StartsWith('[')) { $v = $v.Substring(1) }
    if ($v.EndsWith(']'))   { $v = $v.Substring(0, $v.Length - 1) }
    return @($v -split ',' | ForEach-Object { ConvertFrom-PlanYamlScalar $_ } | Where-Object { $_ })
}

function ConvertTo-PlanYamlFlowList([string[]] $values) {
    return "[$(($values -join ', '))]"
}

# Whether a hand-written `automatable:` value is well-formed: `*` alone, or a comma-separated list of
# step numbers and inclusive ranges (start <= end). The parser throws on a malformed value rather
# than silently reading it as "nothing is automatable".
function Test-PlanAutomatableValue([string] $raw) {
    $v = $raw.Trim()
    if ($v -eq '*') { return $true }
    if ($v -eq '')  { return $false }
    foreach ($item in ($v -split ',')) {
        $t = $item.Trim()
        if ($t -match '^\d+$') { continue }
        if ($t -match '^(\d+)-(\d+)$') { if ([int]$matches[1] -le [int]$matches[2]) { continue } }
        return $false
    }
    return $true
}
# The lifecycle states of a unit, in order:
#   ready-to-refine | ready-for-refined-step-review | ready-to-implement | ready-for-user-review
# Legacy spellings are mapped as a file is read, so the next write migrates it (see the header).
function ConvertTo-CanonicalPlanState([string] $State) {
    switch ($State) {
        'ready-to-plan' { 'ready-to-refine' }
        'checkpointed'  { 'ready-to-implement' }
        default         { $State }
    }
}

function ConvertFrom-PlanFrontmatterYaml([string[]] $Lines) {
    $result = [ordered]@{ State = $null; First = $null; Last = $null; Refined = @()
                          Workflow = $null; Automatable = $null; CommitBranch = $null; CommitRepos = @() }
    $i = 0
    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]
        if ($line -match '^current-unit:\s*$') {
            $j = $i + 1
            while ($j -lt $Lines.Count -and $Lines[$j] -match '^\s+(\S+):\s*(.*)$') {
                $k = $matches[1]; $v = $matches[2]
                if     ($k -eq 'first') { $result.First = ConvertFrom-PlanYamlScalar $v }
                elseif ($k -eq 'last')  { $result.Last  = ConvertFrom-PlanYamlScalar $v }
                elseif ($k -eq 'state') { $result.State  = ConvertFrom-PlanYamlScalar $v }
                $j++
            }
            $i = $j - 1
        } elseif ($line -match '^workflow:\s*(.*)$') {
            $result.Workflow = ConvertFrom-PlanYamlScalar $matches[1]
        } elseif ($line -match '^automatable:\s*(.*)$') {
            $raw = ConvertFrom-PlanYamlScalar $matches[1]
            if (-not (Test-PlanAutomatableValue $raw)) {
                throw "PlanState: malformed 'automatable' value '$raw'."
            }
            $result.Automatable = $raw
        } elseif ($line -match '^commit-grant:\s*$') {
            # Declared by hand, never written by this script - but parsed here so the write side
            # re-emits it instead of deleting it (Write-PlanFrontmatter rebuilds the whole block).
            $j = $i + 1
            while ($j -lt $Lines.Count -and $Lines[$j] -match '^\s+(\S+):\s*(.*)$') {
                $k = $matches[1]; $v = $matches[2]
                if     ($k -eq 'branch') { $result.CommitBranch = ConvertFrom-PlanYamlScalar $v }
                elseif ($k -eq 'repos')  { $result.CommitRepos  = ConvertFrom-PlanYamlFlowList $v }
                $j++
            }
            $i = $j - 1
        } elseif ($line -match '^current-step:\s*$') {
            # Backward compat: pre-rename single-pointer shape (`name`/`state`, no first/last).
            # Read-only - Write-PlanFrontmatter always emits current-unit, so the next
            # Set-PlanState call on this file migrates it.
            $j = $i + 1
            while ($j -lt $Lines.Count -and $Lines[$j] -match '^\s+(\S+):\s*(.*)$') {
                $k = $matches[1]; $v = $matches[2]
                if     ($k -eq 'name')  { $result.First = ConvertFrom-PlanYamlScalar $v; $result.Last = $result.First }
                elseif ($k -eq 'state') { $result.State  = ConvertFrom-PlanYamlScalar $v }
                $j++
            }
            $i = $j - 1
        } elseif ($line -match '^refined:\s*$') {
            $items = @()
            $j = $i + 1
            while ($j -lt $Lines.Count -and $Lines[$j] -match '^\s*-\s*(.*)$') {
                $items += ConvertFrom-PlanYamlScalar $matches[1]
                $j++
            }
            $result.Refined = $items
            $i = $j - 1
        }
        $i++
    }

    $result.State = ConvertTo-CanonicalPlanState $result.State
    # Fill the pair here, not only on the write side: `-Advance` finds the current step by `Last`,
    # and a one-step unit no longer writes one down.
    if ($result.First -and -not $result.Last) { $result.Last  = $result.First }
    if ($result.Last  -and -not $result.First) { $result.First = $result.Last }

    return $result
}

# `last` is the marker of a batched multi-step unit, so it is written down only when it differs from
# `first`.
function ConvertTo-PlanFrontmatterYaml([hashtable] $Frontmatter) {
    $out = @()
    $first = $Frontmatter.First
    $last  = $Frontmatter.Last
    if ($first -or $last -or $Frontmatter.State) {
        $out += "current-unit:"
        if ($first) { $out += "  first: $(ConvertTo-PlanYamlScalar $first)" }
        if ($last -and $last -ne $first) { $out += "  last: $(ConvertTo-PlanYamlScalar $last)" }
        if ($Frontmatter.State) { $out += "  state: $($Frontmatter.State)" }
    }
    if ($Frontmatter.Workflow) { $out += "workflow: $($Frontmatter.Workflow)" }
    if ($Frontmatter.Automatable) { $out += "automatable: $($Frontmatter.Automatable)" }
    if (@($Frontmatter.Refined).Count -gt 0) {
        $out += "refined:"
        foreach ($item in @($Frontmatter.Refined)) {
            $out += "  - $(ConvertTo-PlanYamlScalar $item)"
        }
    }
    if ($Frontmatter.CommitBranch) {
        $out += "commit-grant:"
        $out += "  branch: $(ConvertTo-PlanYamlScalar $Frontmatter.CommitBranch)"
        if (@($Frontmatter.CommitRepos).Count -gt 0) {
            $out += "  repos: $(ConvertTo-PlanYamlFlowList @($Frontmatter.CommitRepos))"
        }
    }
    return $out
}

# Returns $LineArray's lines as a plain string array (empty array if it has none).
function Get-PlanLines([LineArray] $LineArray) {
    if ($LineArray.IsEmpty()) { return @() }
    return (ConvertTo-UnixLineEndings $LineArray.ToString()) -split "`n"
}

# Locates the frontmatter block (if any) at the top of $LineArray.
# Returns @{ Frontmatter=<hashtable>; Range=<range covering both '---' delimiters> }.
# If no frontmatter block is present, Range is the empty range @{idxFirst=0; idxLast=-1} - i.e.
# where ReplaceLines should insert a new one.
function Find-PlanFrontmatter([LineArray] $LineArray) {
    $fm = [ordered]@{ State = $null; First = $null; Last = $null; Refined = @()
                      Workflow = $null; Automatable = $null; CommitBranch = $null; CommitRepos = @() }
    $range = @{ idxFirst = 0; idxLast = -1 }

    $hasOpener = -not $LineArray.IsEmpty() -and
        ($LineArray.GetLines(@{idxFirst = 0; idxLast = 0}).ToString() -eq '---')
    if ($hasOpener) {
        $closeIdx = Find-MatchingLine $LineArray @{idxFirst = 1; idxLast = $LineArray.GetLineCount() - 1} '^---$'
        if ($closeIdx -ge 0) {
            $yamlLines = Get-PlanLines ($LineArray.GetLines(@{idxFirst = 1; idxLast = $closeIdx - 1}))
            $fm = ConvertFrom-PlanFrontmatterYaml $yamlLines
            $range = @{ idxFirst = 0; idxLast = $closeIdx }
        }
    }

    return @{ Frontmatter = $fm; Range = $range }
}

function Write-PlanFrontmatter([string] $PlanFile, [LineArray] $LineArray, $Range, [hashtable] $Frontmatter) {
    $yamlLines = ConvertTo-PlanFrontmatterYaml $Frontmatter
    $blockText = (@('---') + $yamlLines + @('---')) -join $LineArray.GetNl()
    $newBlock  = [LineArray]::new($blockText)
    $LineArray.ReplaceLines($Range, $newBlock)
    [System.IO.File]::WriteAllText($PlanFile, $LineArray.ToString(), [System.Text.UTF8Encoding]::new($false))
}

function Get-PlanState([string] $PlanFile) {
    $PlanFile = Expand-TildePath $PlanFile
    $raw = if (Test-Path $PlanFile) { [System.IO.File]::ReadAllText($PlanFile) } else { '' }
    $la = [LineArray]::new($raw)
    $found = Find-PlanFrontmatter $la
    # HasSteps distinguishes a skeleton - a file whose steps haven't been worked out yet - from a
    # plan with a step to point at. GetLines yields nothing for the inverted range a body-less file
    # produces.
    $bodyRange = @{ idxFirst = $found.Range.idxLast + 1; idxLast = $la.GetLineCount() - 1 }
    $stepHeadings = @(Get-PlanStepHeadings $la $bodyRange)
    return [pscustomobject]@{
        State    = $found.Frontmatter.State
        First    = $found.Frontmatter.First
        Last     = $found.Frontmatter.Last
        Refined  = @($found.Frontmatter.Refined)
        Workflow = $found.Frontmatter.Workflow
        Automatable = $found.Frontmatter.Automatable
        CommitBranch = $found.Frontmatter.CommitBranch
        CommitRepos  = @($found.Frontmatter.CommitRepos)
        HasFrontmatter = ($found.Range.idxLast -ge 0)
        HasSteps       = ($stepHeadings.Count -gt 0)
        StepHeadings   = $stepHeadings
    }
}

function Get-PlanStepHeadings([LineArray] $LineArray, $BodyRange) {
    $headings = @()
    foreach ($line in (Get-PlanLines ($LineArray.GetLines($BodyRange)))) {
        if ($line -match '^#{2,}\s+(Step\b.*)$') {
            $headings += $matches[1].Trim()
        }
    }
    return $headings
}

function Get-PlanStepId([string] $HeadingOrRef) {
    if ($HeadingOrRef -match '^(Step\s+[^\s:]+)') {
        return ($matches[1] -replace '\s+', ' ').Trim().ToLowerInvariant()
    }
    return ($HeadingOrRef -replace '\s+', ' ').Trim().ToLowerInvariant()
}

function Set-PlanState {
    param(
        [Parameter(Mandatory)] [string] $PlanFile,
        [string] $State,
        [string] $First,
        [string] $Last,
        [string[]] $Refined,
        [switch] $Advance,
        [string] $ToStep,
        [string] $Workflow,
        [string] $CommitBranch,
        [string[]] $CommitRepos
    )

    # The pointer is re-pointed as a whole, and only one parameter set at a time says where to.
    if ($Advance -and ($PSBoundParameters.ContainsKey('First') -or $PSBoundParameters.ContainsKey('Last'))) {
        throw "Set-PlanState: -Advance names its target with -ToStep, not -First/-Last."
    }
    if ($PSBoundParameters.ContainsKey('Last') -and -not $PSBoundParameters.ContainsKey('First')) {
        throw "Set-PlanState: -Last needs -First."
    }

    $PlanFile = Expand-TildePath $PlanFile
    $raw = if (Test-Path $PlanFile) { [System.IO.File]::ReadAllText($PlanFile) } else { '' }
    $la = [LineArray]::new($raw)
    $found = Find-PlanFrontmatter $la
    $fm = $found.Frontmatter
    $range = $found.Range

    if ($Advance) {
        $bodyRange = @{ idxFirst = $range.idxLast + 1; idxLast = $la.GetLineCount() - 1 }
        $headings = @(Get-PlanStepHeadings $la $bodyRange)
        if (@($headings).Count -eq 0) {
            if ($fm.Last) {
                # /wrap on the last remaining step: its body was cut to the done file before the
                # pointer was advanced, so the pointer names a step that is no longer in the file
                # and nothing is left to point at. That is a finished plan, and the pointer's step
                # is what the user reviews (the branch), so it lands at ready-for-user-review,
                # leaving the pointer on the closed step, rather than throwing.
                $fm.State = 'ready-for-user-review'
                Write-PlanFrontmatter $PlanFile $la $range $fm
                return (Get-PlanState $PlanFile)
            }
            throw "Set-PlanState: no step headings found in '$PlanFile' - cannot advance."
        }

        if ($ToStep) {
            $targetId = Get-PlanStepId $ToStep
            $target = @($headings) | Where-Object { (Get-PlanStepId $_) -eq $targetId } | Select-Object -First 1
            if (-not $target) {
                throw "Set-PlanState: step '$ToStep' not found among plan headings."
            }
        } else {
            # Advance from the current unit's *last* step - a unit-of-1 has first == last, so this
            # is exactly today's single-step behavior; a multi-step unit advances past its end.
            $currentId = if ($fm.Last) { Get-PlanStepId $fm.Last } else { $null }
            $target = $null
            if ($currentId) {
                $idx = -1
                for ($i = 0; $i -lt $headings.Count; $i++) {
                    if ((Get-PlanStepId $headings[$i]) -eq $currentId) { $idx = $i; break }
                }
                if ($idx -ge 0 -and $idx + 1 -ge $headings.Count) {
                    throw "Set-PlanState: '$($fm.Last)' is the last step in '$PlanFile' - no next step to advance to."
                }
                if ($idx -ge 0) { $target = $headings[$idx + 1] }
            }
            # Either no pointer at all (a brand-new plan getting its first one), or a pointer whose
            # steps are no longer in the file - which is every /wrap close, since it cuts the unit to
            # the done file before advancing. Completed steps leave the plan, so the first remaining
            # heading is the earliest unfinished step in both cases.
            if (-not $target) { $target = $headings[0] }
        }

        $targetId = Get-PlanStepId $target
        $refinedList = @($fm.Refined)
        $matchIdx = -1
        for ($i = 0; $i -lt $refinedList.Count; $i++) {
            if ((Get-PlanStepId $refinedList[$i]) -eq $targetId) { $matchIdx = $i; break }
        }

        # -Advance always resets the extent to a single new step - a batched multi-step unit is
        # declared by hand and re-pointed with -First/-Last (see PlanState.ps1 header).
        $fm.First = $target
        $fm.Last  = $target

        if ($matchIdx -ge 0) {
            $fm.State = 'ready-to-implement'
            $newRefined = @()
            for ($i = 0; $i -lt $refinedList.Count; $i++) {
                if ($i -ne $matchIdx) { $newRefined += $refinedList[$i] }
            }
            $fm.Refined = $newRefined
        } else {
            $fm.State = 'ready-to-refine'
        }
    } else {
        if ($PSBoundParameters.ContainsKey('State')) { $fm.State = ConvertTo-CanonicalPlanState $State }
        if ($PSBoundParameters.ContainsKey('First')) {
            if ($PSBoundParameters.ContainsKey('Last')) {
                $fm.Last = $Last
            } elseif ($fm.Last -eq $fm.First) {
                # A unit of 1 re-points whole. The read side fills `last` in from `first`, so moving
                # only `first` would leave the old name behind as a batched unit's other end.
                $fm.Last = $First
            } else {
                # Which end the caller meant is unknowable here, and both readings lose something: a
                # renumber that re-points only `first` leaves a stale `last`, while collapsing to a
                # unit of 1 discards a hand-declared extent.
                throw "Set-PlanState: '$PlanFile' holds a batched unit ('$($fm.First)' .. '$($fm.Last)') - pass -Last as well as -First to re-point it."
            }
            $fm.First = $First
        }
        if ($PSBoundParameters.ContainsKey('Refined')) { $fm.Refined = @($Refined) }
    }

    # Independent of the pointer-advance logic above, and applied whether or not -Advance was
    # also passed.
    if ($PSBoundParameters.ContainsKey('Workflow')) { $fm.Workflow = $Workflow }
    if ($PSBoundParameters.ContainsKey('CommitBranch')) { $fm.CommitBranch = $CommitBranch }
    if ($PSBoundParameters.ContainsKey('CommitRepos')) { $fm.CommitRepos = @($CommitRepos) }


    Write-PlanFrontmatter $PlanFile $la $range $fm
    return Get-PlanState $PlanFile
}

# Maps plan lifecycle state to a display stage label — "what is happening", not the stored state
# itself. A state with no recognized label, or none at all, keeps 'planning': that's where initial
# working-out of the steps actually sits.
function Get-PlanStageLabel([string] $state) {
    switch ($state) {
        'ready-to-refine'               { 'refining' }
        'ready-for-refined-step-review' { 'refining' }
        'ready-to-implement'            { 'coding' }
        'ready-for-user-review'         { 'reviewing' }
        default                         { 'planning' }
    }
}