# Skill groups contributed by the prat layer.
# Layers contribute named skill groups; the top layer composes them into roles. See Get-AgentRoles.
@{
    skillGroups = @{
        # Everyday dev skills, usable in any repo (pratified or not).
        core = @(
            'working-with-git', 'run-tests', 'testing', 'windows-edit-recovery',
            'review-changes', 'reviewing-a-pr', 'stepped-review', 'simplify', 'audit-code',
            'remember', 'reflect', 'you-are-stateless',
            'plan-format', 'pr-workflow', 'start-plan', 'wrap', 'wrap-session', 'ready-for-user-review', 'land-step',
            'plan-refine-next-step'
        )
        # Prat-ecosystem development (i.e. working in any pratified projects, such as prat, prefs, de).
        pratDev = @(
            'pratified-dev-loop', 'pratify-a-project', 'working-in-prat', 'pwsh-coding', 'python-patterns',
            'check-prat-layers'
        )
    }
    # Harness allowlists — skills only applicable to specific harnesses. A skill absent from this map,
    # applies to every harness. See Get-AgentRoles.
    skillHarnesses = @{
        'windows-edit-recovery' = @('cc')
    }
}
# OmitFromCoverageReport: a unit test would just restate it - static skill-group data
