# .SYNOPSIS
# Bootstraps the prat script environment when it isn't already loaded.
#
# .NOTES
# Dev-loop scripts (Test-Codebase, Build-Codebase, ...) depend on functions the prat profile
# provides (Get-PratProject, Expand-TildePath, ...). When invoked from a harness that launches
# `pwsh -NoProfile` (e.g. an agent tool), the profile never runs and those functions are absent.
#
# Dot-source this from such scripts to make them profile-independent. It's a no-op in interactive
# shells and in tests that import PratBase, where the environment is already present.
#
# Must be dot-sourced (not `&`) so the environment lands in the caller's scope.
if (-not (Test-Path Function:\Get-PratProject)) {
    # For an agent tool, progress UI renders as noise here, and output redirection
    # isn't detectable, so we're using this 'if' to detect when to suppress progress UI.
    #
    # Interactive and install flows don't hit this branch.
    $global:ProgressPreference = 'SilentlyContinue'

    . "$PSScriptRoot\scriptProfile.ps1"
}
