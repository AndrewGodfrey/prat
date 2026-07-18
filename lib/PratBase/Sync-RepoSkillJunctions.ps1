# Reconcile directory junctions under $SkillsDir so that curated skills from a target repo appear
# alongside an agent role's deploy-copied skills, without copying them. Re-run each launch so it
# self-heals across branch switches and config edits.
#
# Each entry in $RepoSkills: @{ repo = <repo id>; from = <subpath under repo root>; skills = @(<name>...) }
# For each desired skill whose source dir exists, ensures a junction
#   <SkillsDir>/<skill>  ->  <repoRoot>/<from>/<skill>
#
# Reconciliation rules:
#   - A skill is "desired" only if its repo resolves AND its source dir currently exists.
#   - Junctions under $SkillsDir that aren't desired (de-listed, unregistered repo, or vanished
#     source) are removed. Removal deletes only the link, never the target's contents.
#   - Only junction-type dirs are ever removed. Regular dirs (deploy-copied layer skills) are left
#     untouched; on a name collision with one, the layer skill wins (skip + warn).
#   - When a skill is declared by more than one source, the first wins (skip + warn).
#
# $ResolveRepoRoot: { param($repoId) -> <root path> or $null }. Unregistered repos are skipped + warned.
function Sync-RepoSkillJunctions {
    [CmdletBinding()]
    param(
        [object[]] $RepoSkills,
        [Parameter(Mandatory)] [string] $SkillsDir,
        [Parameter(Mandatory)] [scriptblock] $ResolveRepoRoot
    )

    # Build the desired map: skill name -> absolute target dir.
    $desired = @{}
    foreach ($entry in @($RepoSkills)) {
        if (-not $entry) { continue }
        $root = & $ResolveRepoRoot $entry.repo
        if (-not $root) {
            Write-Warning "Sync-RepoSkillJunctions: repo '$($entry.repo)' is not registered; skipping its skills."
            continue
        }
        foreach ($skill in @($entry.skills)) {
            if ($desired.ContainsKey($skill)) {
                Write-Warning "Sync-RepoSkillJunctions: skill '$skill' is declared by more than one source; keeping the first."
                continue
            }
            $target = Join-Path $root (Join-Path $entry.from $skill)
            if (-not (Test-Path -LiteralPath $target -PathType Container)) {
                Write-Warning "Sync-RepoSkillJunctions: source '$target' for skill '$skill' does not exist; skipping."
                continue
            }
            $desired[$skill] = (Get-Item -LiteralPath $target).FullName.TrimEnd('\')
        }
    }

    if (-not (Test-Path -LiteralPath $SkillsDir)) {
        New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
    }

    # Prune junctions that are no longer desired. Regular dirs (deploy-copied layer skills) are never touched.
    foreach ($child in Get-ChildItem -LiteralPath $SkillsDir -Directory -Force -ErrorAction SilentlyContinue) {
        if ($child.LinkType -ne 'Junction') { continue }
        if (-not $desired.ContainsKey($child.Name)) {
            [System.IO.Directory]::Delete($child.FullName)
        }
    }

    # Create or re-point desired junctions.
    foreach ($skill in $desired.Keys) {
        $link   = Join-Path $SkillsDir $skill
        $target = $desired[$skill]
        $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
        if ($existing) {
            if ($existing.LinkType -ne 'Junction') {
                Write-Warning "Sync-RepoSkillJunctions: '$skill' already exists as a non-junction skill; leaving it in place."
                continue
            }
            $current = @($existing.Target)[0]
            if ($current -and ([System.IO.Path]::GetFullPath($current).TrimEnd('\') -ieq $target)) { continue }
            [System.IO.Directory]::Delete($link)
        }
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
}
