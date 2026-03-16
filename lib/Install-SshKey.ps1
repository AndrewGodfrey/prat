#Requires -PSEdition Core, Desktop

<#
  Install-SshKey.ps1
  Generates an SSH key, copies the public key to the clipboard, and prompts the user to
  complete the manual registration steps.

  Parameters:
    $KeyName      - Filename for the key (e.g. 'myDevEnv'), placed in ~/.ssh/
    $ManualSteps  - Instructions to display to the user after the key is generated
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $KeyName,
    [Parameter(Mandatory)] [string] $ManualSteps
)

$ErrorActionPreference = "Stop"

$sshdir = "$home\.ssh"
$keypath = "$sshdir\$KeyName"
$pubpath = "$sshdir\$KeyName.pub"

if (-not (Test-Path $keypath)) {
    Write-Warning "Generating new ssh key at: $keypath"
    # The '""' is required if we happen to be running in powershell.exe (i.e. "Windows PowerShell" and not "Powershell Core"). Which on a clean machine is what we start with.
    ssh-keygen -q -f $keypath -N '""'
    if (-not (Test-Path $keypath) -or -not (Test-Path $pubpath)) {
        throw "Failure to generate file: $keypath"
    }
    $publicKey = Get-Content $pubpath
    $publicKey | Set-Clipboard
    Write-Warning @"
I've put the public key in the clipboard. Or you can copy it from here: $publicKey
Manual steps:
$ManualSteps
"@
    pause
}
