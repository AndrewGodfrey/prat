using module ..\TextFileEditor\TextFileEditor.psd1
using module ..\PratBase\PratBase.psd1

# PlanState.ps1
# CRLF-safe create/read/update for the plan-lifecycle frontmatter: current-unit (a contiguous run
# of one or more steps, `first`/`last`, plus `state`) and `refined`. The model never hand-edits
# these — only this script writes them.
#
# A "unit" is the pointer's granularity: `first == last` is the common single-step case
# (workflow 1); `first != last` is a batched multi-step unit (workflow 2) — the pointer stays
# fixed at the unit's extent through implementation and review, and `-Advance` moves past `last`
# to the next single-step unit. See newHarness.md's "Generalize the plan pointer" step for the
# design rationale.
#
# Read side also accepts the pre-rename `current-step: { name, state }` shape, for plans not yet
# migrated (e.g. on a machine where this file hasn't landed yet). Write side always emits
# current-unit - so any Set-PlanState call on such a file migrates it, even a no-op call
# (`Set-PlanState -PlanFile <path>`) made solely to force the rewrite.
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

function ConvertFrom-PlanFrontmatterYaml([string[]] $Lines) {
    $result = [ordered]@{ State = $null; First = $null; Last = $null; Refined = @() }
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
    return $result
}

# Invariant: once either of first/last is set, both are emitted - a unit-of-1 write (only one
# supplied) fills the other so a reader never sees a lone half of the pair.
function ConvertTo-PlanFrontmatterYaml([hashtable] $Frontmatter) {
    $out = @()
    $first = $Frontmatter.First
    $last  = $Frontmatter.Last
    if ($first -and -not $last) { $last = $first }
    if ($last -and -not $first) { $first = $last }
    if ($first -or $Frontmatter.State) {
        $out += "current-unit:"
        if ($first) { $out += "  first: $(ConvertTo-PlanYamlScalar $first)" }
        if ($last)  { $out += "  last: $(ConvertTo-PlanYamlScalar $last)" }
        if ($Frontmatter.State) { $out += "  state: $($Frontmatter.State)" }
    }
    if (@($Frontmatter.Refined).Count -gt 0) {
        $out += "refined:"
        foreach ($item in @($Frontmatter.Refined)) {
            $out += "  - $(ConvertTo-PlanYamlScalar $item)"
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
    $fm = [ordered]@{ State = $null; First = $null; Last = $null; Refined = @() }
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
    $found = Find-PlanFrontmatter ([LineArray]::new($raw))
    return [pscustomobject]@{
        State    = $found.Frontmatter.State
        First    = $found.Frontmatter.First
        Last     = $found.Frontmatter.Last
        Refined  = @($found.Frontmatter.Refined)
        HasFrontmatter = ($found.Range.idxLast -ge 0)
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
        [string[]] $Refined,
        [switch] $Advance,
        [string] $ToStep
    )

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
                if ($idx -ge 0 -and $idx + 1 -lt $headings.Count) {
                    $target = $headings[$idx + 1]
                } elseif ($idx -ge 0) {
                    throw "Set-PlanState: '$($fm.Last)' is the last step in '$PlanFile' - no next step to advance to."
                }
            }
            if (-not $target) { $target = $headings[0] }
        }

        $targetId = Get-PlanStepId $target
        $refinedList = @($fm.Refined)
        $matchIdx = -1
        for ($i = 0; $i -lt $refinedList.Count; $i++) {
            if ((Get-PlanStepId $refinedList[$i]) -eq $targetId) { $matchIdx = $i; break }
        }

        # -Advance always resets the extent to a single new step - a batched multi-step unit's
        # `last` is only ever extended by hand-editing the frontmatter (see PlanState.ps1 header).
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
            $fm.State = 'ready-to-plan'
        }
    } else {
        if ($PSBoundParameters.ContainsKey('State')) { $fm.State = $State }
        if ($PSBoundParameters.ContainsKey('First')) { $fm.First = $First }
        if ($PSBoundParameters.ContainsKey('Refined')) { $fm.Refined = @($Refined) }
    }

    Write-PlanFrontmatter $PlanFile $la $range $fm
    return Get-PlanState $PlanFile
}