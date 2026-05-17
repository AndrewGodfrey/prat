---
name: check-prat-layers
description: Pre-commit check for prat-ecosystem public repos (prat, prefs). Runs Find-SensitiveData and Find-LayerViolations with merged configs. De contributes augmentation rules but is not scanned.
---

# check-prat-layers

Scans all installed prat-ecosystem public repos (prat, prefs) for layer violations and sensitive
data. Run before finalizing any feature branch or direct commit to a public repo.

## How to run

```bash
pwsh -c '& "$home/prat/lib/agents/skills/check-prat-layers/check-prat-layers.ps1"'
```

## After running

- If all outputs report clean: all installed repos pass — proceed with the commit or merge.
- If any violations found: fix them and re-run before committing.
- Also verify manually that no file contains tokens, passwords, API keys, SSH private keys,
  machine names, hostnames, or internal URLs — `Find-SensitiveData` does not detect these.
