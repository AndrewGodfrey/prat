# Prat's "override" mechanism

This is for making your own custom dev environment, using Prat as a base.

Mechanisms are provided so that you can 'override' various things in Prat:

- You can put things in $env:Path earlier than Prat's binpaths. See Install-PratBinPathOverride.ps1.
- Using that, you can override Prat scripts like 'Get-DevEnvironments.ps1'. And maybe others like 'Get-CodebaseScript.ps1' (but I'm thinking maybe I should standardize on using Get-DevEnvironments). 
- Using Resolve-PratLibFile.ps1, you can override Powershell startup ('profile') behavior. See add your own powershell profile" can mix custom things with Prat's profile.


## Shouldn't this be more flexible?

### Multiple dev envs (one per machine)
It's logical to have distinct dev envs for different machines - e.g. personal, school, work, test machine.
This design supports that.

I still recommend sharing "your" customization between these environments, as much as you can.
e.g. My 'personal' environment installs an "Install-MyPrat.ps1" script somewhere I can use from all of them.


### Multiple dev envs on a single machine
I could imagine someone wanting to have more than one overridden devenv on one machine, but that would be more complicated
and I think it's confusing too.

The design philosophy I'm following here is:

One human should use "one" dev environment. It might be specific to them, or they might share parts of it with others, but they shouldn't have more than one.
This is a "human-computer interface", and all codebases should be subservient to that. So if you have to work with some codebase that thinks of itself
as being 'your' interface, don't let it. Isolate it. e.g. see Invoke-CommandWithEnvDelta. (I could imagine needing even more isolation for some codebases - if they
install something really obnoxious, they might need to be sandboxed.)

So then (returning to the previous section) if you do have different dev envs on different machines - they should still try to use
the same human-computer interface as much as possible. e.g. I arrange for "b" to build on all of them (as much as possible - 
yes I still live with some edge cases, but the cognitive load is still much lower).


### Nested dev envs
I could also imagine someone wanting it to be nestable. This makes sense:
- instead of customizing Prat, you might piggyback on someone else's customization.
- or, you could have some common customization, and then on a work machine some work-specific customization

I've started in that direction by making Get-DevEnvironments.ps1 return an array. (i.e. a 'stack' of devenvs).
But more work is needed.