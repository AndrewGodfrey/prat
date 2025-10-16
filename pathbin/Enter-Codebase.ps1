# .SYNOPSIS
# 'Enters' a codebase, by launching a child Powershell session with the codebase's cached env-vars applied.
# When done you can use Powershell's "exit" command to return to the parent session.
#
# Alias: ec
#
# .NOTES
# This is not the same as starting a codebase-specific enlistment window. For many codebases, they make you
# wait while they update packages and env-vars. Enter-Codebase just applies previously-cached env-vars so
# it's fast. If you want to update the packages and cached env-vars, that's a different command:
#   Prebuild-Codebase -Force
# (alias: pb)
#
# The current state is shown in the prompt.
# It's not ideal that the codebase name is used twice in the prompt for different things (applied environment, and pwd).
#
# .EXAMPLE
#   [llamacpp](CMake)
#   > Enter-Codebase
#   [[ENV: %llamacpp%]] [llamacpp](CMake)
#   >
#
Open-CodebaseWorkspace.ps1 {pwsh -NoExit -Command "cd $pwd"} -DescriptionScript {param($cbtId); "Entering: $cbtId" }

# OmitFromCoverageReport: a unit test would just restate it