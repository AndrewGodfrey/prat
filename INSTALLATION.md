# Installation

You shouldn't blindly trust scripts from the internet! First consider:

1. if you trust this repo
2. if your workflow will be disrupted by the customizations it makes. This script will:
   - install various things (e.g. git, a sudo implementation, Pester)
   - invoke its build/test/deploy loop, unless you add the `-SkipDeployStep` switch. See `Deploy-Prat.ps1`for the things that can install.
   - in particular, it will install a Powershell `profile.ps1`. If you already have one, it will back it up to "profile.original.prat.ps1",
     but you'll need to integrate manually with however you install/maintain your profile. See 'Customization' below for more.

## When ready to install
From a regular (non-elevated) Powershell window:
```powershell
  curl.exe -L -o $env:temp\Install-Prat.ps1 https://github.com/AndrewGodfrey/prat/raw/main/lib/Install-Prat.ps1; Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force; . $env:temp\Install-Prat.ps1
  ```


## Customization
- You can override the profile, see `lib/profile/profilePicker.ps1`. You can either control when to invoke `interactiveProfile_prat.ps1`, or skip
  it entirely to pick-and-choose things from Prat.
- I haven't (yet) made it easy to avoid updating profile.ps1 (aside from the `-SkipDeployStep` option on `Install-Prat.ps1`). The reason is,
  the "one environment for many projects" goal means that Prat needs to defend against projects like 'conda' which edit your `profile.ps1` to
  change your global environment.
- See `Installers.psd1` for other tools you may find useful. e.g. `Install-CustomBrowserHomePage` generates a home-page with search boxes and links;
  there are example input files in `lib\installers\example`.
