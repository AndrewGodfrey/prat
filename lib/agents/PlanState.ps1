using module ..\TextFileEditor\TextFileEditor.psd1

# PlanState.ps1
# CRLF-safe create/read/update for the three plan-lifecycle frontmatter keys: state, next-step,
# refined. The model never hand-edits these — only this script writes them.
#
# Line-ending detection/preservation and range-based splicing are delegated to TextFileEditor's
# LineArray class; this file only owns the YAML shape and the step-pointer/advance logic.

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
    $result = [ordered]@{ State = $null; NextStep = $null; Refined = @() }
    $i = 0
    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]
        if ($line -match '^state:\s*(.*)$') {
            $result.State = ConvertFrom-PlanYamlScalar $matches[1]
        } elseif ($line -match '^next-step:\s*(.*)$') {
            $result.NextStep = ConvertFrom-PlanYamlScalar $matches[1]
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

function ConvertTo-PlanFrontmatterYaml([hashtable] $Frontmatter) {
    $out = @()
    if ($Frontmatter.State) { $out += "state: $($Frontmatter.State)" }
    if ($Frontmatter.NextStep) { $out += "next-step: $(ConvertTo-PlanYamlScalar $Frontmatter.NextStep)" }
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
    $fm = [ordered]@{ State = $null; NextStep = $null; Refined = @() }
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
    $raw = if (Test-Path $PlanFile) { [System.IO.File]::ReadAllText($PlanFile) } else { '' }
    $found = Find-PlanFrontmatter ([LineArray]::new($raw))
    return [pscustomobject]@{
        State    = $found.Frontmatter.State
        NextStep = $found.Frontmatter.NextStep
        Refined  = @($found.Frontmatter.Refined)
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
        [string] $NextStep,
        [string[]] $Refined,
        [switch] $Advance,
        [string] $ToStep
    )

    $raw = if (Test-Path $PlanFile) { [System.IO.File]::ReadAllText($PlanFile) } else { '' }
    $la = [LineArray]::new($raw)
    $found = Find-PlanFrontmatter $la
    $fm = $found.Frontmatter
    $range = $found.Range

    if ($Advance) {
        $bodyRange = @{ idxFirst = $range.idxLast + 1; idxLast = $la.GetLineCount() - 1 }
        $headings = Get-PlanStepHeadings $la $bodyRange
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
            $currentId = if ($fm.NextStep) { Get-PlanStepId $fm.NextStep } else { $null }
            $target = $null
            if ($currentId) {
                $idx = -1
                for ($i = 0; $i -lt $headings.Count; $i++) {
                    if ((Get-PlanStepId $headings[$i]) -eq $currentId) { $idx = $i; break }
                }
                if ($idx -ge 0 -and $idx + 1 -lt $headings.Count) {
                    $target = $headings[$idx + 1]
                } elseif ($idx -ge 0) {
                    throw "Set-PlanState: '$($fm.NextStep)' is the last step in '$PlanFile' - no next step to advance to."
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

        $fm.NextStep = $target
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
        if ($PSBoundParameters.ContainsKey('State'))    { $fm.State = $State }
        if ($PSBoundParameters.ContainsKey('NextStep')) { $fm.NextStep = $NextStep }
        if ($PSBoundParameters.ContainsKey('Refined'))  { $fm.Refined = @($Refined) }
    }

    Write-PlanFrontmatter $PlanFile $la $range $fm
    return Get-PlanState $PlanFile
}
