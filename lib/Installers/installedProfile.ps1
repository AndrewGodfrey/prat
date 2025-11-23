#Requires -PSEdition Core, Desktop

# This file is installed to %userprofile%\Documents\[Windows]Powershell, by Install-PsProfile.ps1.

. $home\prat\lib\profile\initProfileTracing.ps1
pratProfile_trace start "profile.ps1"

. $home\prat\lib\profile\profilePicker.ps1

pratProfile_trace end "profile.ps1"
return

# I don't want 'conda init' to mess with my profile. I'd rather integrate it myself.
# So, give it a place it can mess with, that is ignored.

#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
If (Test-Path "~\anaconda3\Scripts\conda.exe") {
    (& "~\anaconda3\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
}
#endregion

