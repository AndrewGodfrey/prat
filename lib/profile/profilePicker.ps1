# Prat's powershell profile file is 'interactiveProfile_prat.ps1'.
# But it can be overridden by other dev environments. This allows a customized profile to:
# - do some things before starting Prat's profile
# - do some things after running Prat's profile, that depend on things it loads (e.g. PratBase.psd1)
# - or, replace Prat's profile entirely (e.g. it installs something the user doesn't want, and doesn't yet provide enough fine-grained control).
#   (Except for prat's binpaths - if you don't want those, you shouldn't install Prat's profile at all. Some modules
#   are still isolated enough to be usable, but Prat isn't well designed for this.)

# TODO: Move this to lib\override.
# TODO: And rename to "interactiveProfile.ps1"? Or something like "select_interactiveProfile.ps1"?

&$PSScriptRoot\Add-PratBinPaths.ps1

# Now that path is set up, we can use Resolve-PratLibFile.
# Run prat's profile, or an overridden one.
. (Resolve-PratLibFile "lib/profile/interactiveProfile.ps1")
