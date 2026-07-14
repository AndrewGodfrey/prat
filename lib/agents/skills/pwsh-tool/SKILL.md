---
name: pwsh-tool
description: Use when writing any Pwsh script, such as when using the Powershell tool. 
  Covers common gotchas.
---

# Inconsistent ~ handling
Unlike `$home`, Powershell doesn't expand `~` before passing it to things that don't understand it - like external
programs or .NET APIs. So we have to be carefuly to expand it ourselves, in such cases.
Another somewhat surprising case is `pwsh -File ~/...` - that too doesn't expand `~`.

