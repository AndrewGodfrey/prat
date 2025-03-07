# .SYNOPSIS
# Builds, tests and deploys a codebase
# 
# Recommended alias: x
#
# .NOTES
# What this does, depends on the codebase. It might do nothing; it may build stuff and test stuff and deploy to the current machine, or even deploy to remote machines.
# The purpose of this is to provide a consistent dev inner loop.
# 
# Alternatives:
#   - If deploy fails, you may want to skip rerunning tests. That's where I'd use alias 'd' instead of 'x'. 
#   - Similarly for 't', if you're iterating on failing tests and the build step is slow even when there's no work.
#   - I use 'b' more rarely, but on some codebases, it can save time if you're iterating on build errors.
[CmdletBinding()]
param([switch] $Force=$false)

Prebuild-Codebase -Force:$Force
Build-Codebase
Test-Codebase
Deploy-Codebase -Force:$Force

