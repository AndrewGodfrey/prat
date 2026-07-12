# Skill groups contributed by the prat layer.
# Layers contribute named skill groups; the top layer composes them into roles. See Get-AgentRoles.
@{
    skillGroups = @{
        # Everyday dev skills, usable in any repo (pratified or not).
        core = @(
            'working-with-git', 'run-tests', 'testing', 'windows-edit-recovery',
            'review-changes', 'simplify',
            'remember', 'reflect',
            'plan-format', 'start-plan', 'wrap', 'land-step', 'plan-refine-next-step'
        )
        # Prat-ecosystem development (pratified projects: prat, prefs, de).
        pratDev = @('pratified-dev-loop', 'working-in-prat', 'powershell-patterns', 'python-patterns', 'check-prat-layers')
    }
}
