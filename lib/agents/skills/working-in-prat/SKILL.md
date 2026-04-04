---
name: working-in-prat
description: Use when doing any work in the prat codebase or in repos layered on top of prat
  (e.g. `de`, `prefs`) — reading, modifying, debugging, understanding code, or analyzing deploy
  scripts that use prat's package or installer system.
---

## Installers framework conventions

When writing `install` scriptblocks in `$pratPackages`, add `$stage.SetSubstage("description")`
before each long-running operation (network downloads, elevated installs, etc.) to give the user
progress visibility.

Also, for architecture overview, dev loop commands, and codebase structure: read @`$HOME/prat/README.md`
