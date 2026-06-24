---
name: python-patterns
description: Use when setting up a Python project in the prat ecosystem — Python version,
  dependencies, caching.
---

# Python version and compatibility

Python is pinned to **3.12**. See the comment in `instPackages.ps1` for the compatibility rationale.

# Dependency management

`requirements.txt` is for **runtime** dependencies only. Test tools or other SDK-like dependencies
should be installed by `d` e.g. using Install-PratPackage.

# `__pycache__` and `.pyc` files

`scriptProfile.ps1` sets `$env:PYTHONPYCACHEPREFIX`, which redirects all `__pycache__` output
to a system temp location. This applies whenever Python is called as a child of a pwsh process
that loaded the profile. If you're seeing `__pycache__` in source dirs
despite the profile being loaded, the likely cause is a profile-less invocation.

If you want no cache at all (e.g. in a test runner where compilation overhead is negligible and you want zero artifacts), add `-B` to the python invocation explicitly. 
