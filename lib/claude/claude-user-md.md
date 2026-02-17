# Bash tool
- For Bash() commands, always use Bash(pwsh ...). (This is to sidestep filename syntax confusion on Windows, and standardize behavior other OSes. I'll ensure pwsh is available.)
- Must escape `$` in pwsh commands run via Bash tool, e.g. `pwsh -c "& \$env:USERPROFILE\de\pathbin\Deploy-DevEnvironment.ps1"`
- Bash interpolates `$` before pwsh sees it; escaping with `\$` prevents this
- Never redirect to `/dev/null` or `nul`. Use `Out-Null` or similar instead.

# Claude settings

- My dev environment is managed by the `de` and `prat` repos.
- That includes claude user-level configuration, since I use multiple machines and work on multiple projects.
- When making a plan, if claude won't be doing all the steps, label each step with "[USER]" or "[CLAUDE]" as appropriate.