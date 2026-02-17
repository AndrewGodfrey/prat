# Shell preferences

- For Bash() commands, always use Base(pwsh ...). (This is to sidestep syntax confusion on Windows, and standardize behavior other OSes. I'll ensure pwsh is available.)
- Never redirect to `/dev/null` or `nul`. Use `Out-Null` or similar instead.

# Claude settings

- My dev environment is managed by the `de` and `prat` repos.
- That includes claude user-level configuration, since I use multiple machines and work on multiple projects.
- When making a plan, if claude won't be doing all the steps, label each step with "[USER]" or "[CLAUDE]" as appropriate.