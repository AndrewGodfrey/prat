# Resolve layered agent-role definitions into a flat per-role skill map.
#
# Each layer contributes a `lib/agents/roles_<layer>.ps1` returning
#   @{ skillGroups = @{ <groupName> = @(<skill>...) }; skillHarnesses = @{ <skill> = @(<harness>...) }; roles = @{ <roleName> = @{ skillGroups=@(...); skills=@(...); repo=...; repoSkills=@(...); repoAgents=@(...) } } }
# Lower layers (prat) define skill groups; the top layer (de) composes roles from them.
# Groups, harness maps, and roles merge base-first, so a higher layer wins on a name collision.
#
# skillHarnesses is a partial blocklist for harness-specific skills. Harness names
# are opaque strings to prat.
#
# Lives in PratBase (not the Installers module) because it's pure config resolution needed in two
# contexts: at deploy (Install-AgentRoles) and at launch (resolving a role's repoSkills).
#
# Returns @{ <roleName> = @{ skills = @(<resolved skill names>); repo = <optional>; repoSkills = <optional>; repoAgents = <optional> } }.
# Test seams: -Contributions injects already-evaluated definitions (base-first); -RolesFiles injects
# the file list (highest-first, as Resolve-PratLibFile returns it). Normally both are read from disk.
function Get-AgentRoles {
    param([object[]] $Contributions, [string[]] $RolesFiles, [string] $Harness)

    if (-not $PSBoundParameters.ContainsKey('Contributions')) {
        if (-not $PSBoundParameters.ContainsKey('RolesFiles')) {
            $RolesFiles = @(Resolve-PratLibFile 'lib/agents/roles.ps1' -ListAll)   # highest-first
        }
        $files = @($RolesFiles)
        [array]::Reverse($files)                                                  # base-first
        $Contributions = @($files | ForEach-Object { & $_ })
    }

    $mergedGroups    = @{}
    $mergedRoles     = @{}
    $mergedHarnesses = @{}
    foreach ($c in $Contributions) {
        if ($c.skillGroups)    { foreach ($k in $c.skillGroups.Keys)    { $mergedGroups[$k]    = $c.skillGroups[$k] } }
        if ($c.skillHarnesses) { foreach ($k in $c.skillHarnesses.Keys) { $mergedHarnesses[$k] = $c.skillHarnesses[$k] } }
        if ($c.roles)          { foreach ($k in $c.roles.Keys)          { $mergedRoles[$k]     = $c.roles[$k]  } }
    }

    $resolved = @{}
    foreach ($roleName in $mergedRoles.Keys) {
        $role = $mergedRoles[$roleName]
        $skills = @()
        if ($role.skillGroups) {
            foreach ($g in $role.skillGroups) {
                if (-not $mergedGroups.ContainsKey($g)) { throw "Role '$roleName' references unknown skillGroup '$g'" }
                $skills += $mergedGroups[$g]
            }
        }
        if ($role.skills) { $skills += $role.skills }
        if ($Harness) {
            $skills = @($skills | Where-Object { -not $mergedHarnesses.ContainsKey($_) -or $Harness -in $mergedHarnesses[$_] })
        }

        $entry = @{ skills = @($skills | Select-Object -Unique) }
        if ($role.repo)       { $entry.repo       = $role.repo }
        if ($role.repoSkills) { $entry.repoSkills = $role.repoSkills }
        if ($role.repoAgents) { $entry.repoAgents = $role.repoAgents }
        $resolved[$roleName] = $entry
    }
    return $resolved
}
