# Bash tool
- Always use forward slashes in paths, e.g. `C:/Users/foo` not `C:\Users\foo`. Backslashes will be misinterpreted.
- When running PowerShell commands via Bash, use `pwsh -c "..."`. Must escape `$`, e.g. `pwsh -c "& \$env:USERPROFILE/de/pathbin/Deploy-DevEnvironment.ps1"` — otherwise Bash interpolates `$` before pwsh sees it.
- To discard output: in bash use `> /dev/null`, in pwsh use `| Out-Null` or `> \$null`. Never use `> nul` in bash (it creates a literal file).

# Claude settings

- My dev environment is managed by the `de` and `prat` repos.
- That includes claude user-level configuration, since I use multiple machines and work on multiple projects.
- When making a plan, if claude won't be doing all the steps, label each step with "[USER]" or "[CLAUDE]" as appropriate.

# Tools
```powershell
# Locate the `prat` repo, and the 'de' repo if present
Get-DevEnvironments.ps1

# List codebases on this machine
Get-GlobalCodebases.ps1
```
