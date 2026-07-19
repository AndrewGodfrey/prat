# Skill groups contributed by the prat layer.
# Layers contribute named skill groups; the top layer composes them into roles. See Get-AgentRoles.
@{
    skillGroups = @{
        # Everyday dev skills, usable in any repo (pratified or not).
        core = @(
            'working-with-git', 'run-tests', 'testing', 'windows-edit-recovery',
            'review-changes', 'simplify',
            'remember', 'reflect',
            'plan-format', 'start-plan', 'wrap', 'wrap-session', 'code-complete', 'land-step',
            'plan-refine-next-step', 'pwsh-tool'
        )
        # Prat-ecosystem development (i.e. working in any pratified projects, such as prat, prefs, de).
        pratDev = @('pratified-dev-loop', 'working-in-prat', 'pwsh-coding', 'python-patterns', 'check-prat-layers')
    }
}
# OmitFromCoverageReport: a unit test would just restate it - static skill-group data
