# The skill source dirs that exist across the installed layers, base-first:
# the order in which a higher layer's same-named skill overwrites a lower layer's.
#
# Lives in PratBase, beside Get-AgentRoles, rather than in the Installers module: it's pure config
# resolution, and higher layers resolve the same list to give their own harnesses the skill set that
# deploy installs into a role dir.
#
# Test seam: -Layers injects the layer list (highest-first, as Get-CodebaseLayers returns it).
function Get-AgentSkillSources {
    param([object[]] $Layers)

    if (-not $PSBoundParameters.ContainsKey('Layers')) { $Layers = @(Get-CodebaseLayers) }

    $baseFirst = @($Layers)
    [array]::Reverse($baseFirst)
    foreach ($layer in $baseFirst) {
        $dir = Join-Path $layer.Path 'lib/agents/skills'
        if (Test-Path $dir) { $dir }
    }
}
