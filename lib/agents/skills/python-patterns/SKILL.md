---
name: python-patterns
description: Use when setting up a Python project in the prat ecosystem — Python version,
  dependencies, caching.
---

# Python version and compatibility

Python is pinned to **3.12**. See the comment in `instPackages.ps1` for the compatibility rationale.

# sys.path and PYTHONPATH

`python312._pth` (in the Python install dir) suppresses `PYTHONPATH` — setting it has no effect.
However, running `python script.py` still adds the script's own directory to `sys.path[0]`
automatically, so same-directory imports work without boilerplate.

For cross-repo imports (e.g. de code importing from prat), use `pip install -e` on the source
package or add the path in the launcher script — not `sys.path.insert` in production source files.

Give pip-installed packages in this ecosystem a distinct top-level name (e.g. `prat_foo_parser`,
not `parser`) — a generic name risks colliding with another package in the same shared
site-packages. A shared `sys.path`-mutating helper module (import it first, it inserts paths as a
side effect) is not a substitute: it just relocates the same anti-pattern into one file instead of
removing it, and becomes its own hardcoded map to maintain. PEP 420 implicit namespace packages
(`prat.foo`, `prat.bar`) are a real alternative but editable installs of namespace packages are a
known-flaky corner of pip/setuptools — not worth it until the number of prat-prefixed packages
grows enough to justify the complexity.

# Dependency management

`requirements.txt` is for **runtime** dependencies only. Test tools or other SDK-like dependencies
should be installed by `d` e.g. using Install-PratPackage.

# `__pycache__` and `.pyc` files

`scriptProfile.ps1` sets `$env:PYTHONPYCACHEPREFIX`, which redirects all `__pycache__` output
to a system temp location. This applies whenever Python is called as a child of a pwsh process
that loaded the profile. If you're seeing `__pycache__` in source dirs
despite the profile being loaded, the likely cause is a profile-less invocation.

If you want no cache at all (e.g. in a test runner where compilation overhead is negligible and you want zero artifacts), add `-B` to the python invocation explicitly. 
