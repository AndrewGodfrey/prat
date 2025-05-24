# Basic functions that Prat needs everywhere, and that we'll always load in script and user profile.


# Tests whether the current user has elevated to administrator.
#
# Note: NOT to be confused with "are they a member of the Administrators group?".
function Get-CurrentUserIsElevated {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator"
    )
}


function Get-RelativePath($expectedRoot, $path) {
    if (-not (Split-Path $expectedRoot -IsAbsolute)) { throw "Expected absolute root path. Actual: $expectedRoot" }
    if (-not (Split-Path $path -IsAbsolute)) { throw "Expected absolute path. Actual: $path" }
    if (-not (Test-Path -LiteralPath $path)) { throw "Expected literal path to existing item. Actual: $path" } # Because we're using Resolve-Path, which only works for existing items.

    $canonicalRoot = (Resolve-Path $expectedRoot).Path
    $canonicalPath = (Resolve-Path $path).Path
    if (-not ($canonicalPath.StartsWith($canonicalRoot, 'InvariantCultureIgnoreCase'))) { throw "Expected subpath. '$root' does not seem to be a root of '$path'" }
    if ($canonicalPath -eq $canonicalRoot) { return "" }

    # "+1" to strip off leading path separator.
    return $canonicalPath.SubString($canonicalRoot.Length + 1)
}

# This is analogous to Import-Alias -Force, just with a different file format (and fewer properties supported).
function Import-PratAliases($file) {
    . $file
    foreach ($name in $installedAliases.Keys) {
        $value = $installedAliases[$name]
        New-Alias -Force -Name $name -Value $value -Scope Global
    }
}


###############################################################################
# Description:  Convert Bytes into the appropriate unit of measure
# Author:       Unknown. But seems derived from Ed Wilson's blog: https://devblogs.microsoft.com/scripting/hey-scripting-guy-can-you-give-all-the-steps-for-creating-installing-and-using-windows-powershell-modules/
# Last Update:  5/08/2010 2:03:57 PM
# Arguments:    [int64] The byte value to be converted
# Returns:      [string] Display friendly value
###############################################################################
function Get-OptimalSize($sizeInBytes) {
    if ($null -eq $sizeInBytes) { return $null }
    $sizeInBytes = [int64] $sizeInBytes

    switch ($sizeInBytes) {
        # Hmm. Disk size standards have changed. Nowadays, 1024 bytes is "one kibibyte, abbreviated KiB", and that unit is rarely used.
        # And KB means 1000 bytes. So, instead of using Powershell's definitions for 1TB, 1GB, 1MB or 1KB:
        {$sizeInBytes -ge 1000000000000000} {"{0:n1}" -f ($sizeInBytes/1000000000000000) + "PB" ; break}
        {$sizeInBytes -ge 1000000000000} {"{0:n1}" -f ($sizeInBytes/1000000000000) + "TB" ; break}
        {$sizeInBytes -ge 1000000000} {"{0:n1}" -f ($sizeInBytes/1000000000) + "GB" ; break}
        {$sizeInBytes -ge 1000000} {"{0:n1}" -f ($sizeInBytes/1000000) + "MB" ; break}
        {$sizeInBytes -ge 1000} {"{0:n1}" -f ($sizeInBytes/1000) + "K" ; break}
        default { $sizeInBytes }
    }
}

. $PSScriptRoot\ConvertTo-Expression.ps1

. $PSScriptRoot\getDiskSpace.ps1

function Get-UserIdleTimeInSeconds {
    if ($null -eq ('UserActivity' -as [type])) {
        Add-Type @"
            using System;
            using System.Runtime.InteropServices;

            public class UserActivity {
                [DllImport("user32.dll")]
                private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

                [StructLayout(LayoutKind.Sequential)]
                private struct LASTINPUTINFO {
                    public uint cbSize;
                    public uint dwTime;
                }

                public static uint GetUserIdleTimeInSeconds() {
                    uint idleTime = 0;
                    LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
                    lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
                    lastInputInfo.dwTime = 0;

                    uint envTicks = (uint)Environment.TickCount;

                    if (GetLastInputInfo(ref lastInputInfo)) {
                        uint lastInputTick = lastInputInfo.dwTime;

                        idleTime = envTicks - lastInputTick;
                    }

                    return idleTime / 1000;
                }
            }
"@
    }

    return [UserActivity]::GetUserIdleTimeInSeconds()
}


# .SYNOPSIS
# Given a name that matches exactly one running process:
# Kills the process, and restarts it.
#
# Caveats:
# - Only works when running non-elevated. Otherwise, the new instance will be elevated, which can cause many problems
#   e.g. with files it creates having the wrong owner. 
#   One could use something like [launchUnelevated](https://sourceforge.net/projects/launchunelevated/)
#   to solve that, but my sense is that that direction is not reliable and it's better to change callers, if feasible.

# TODO: Sort out the inherent confusion between needing to run some installers elevated, and needing to do this non-elevated.
function Restart-Process($nameMatch) {
    if (Get-CurrentUserIsElevated) { throw "Can't do this while elevated" }

    $matches = @(Get-CimInstance Win32_Process | ? { $_.Name -like $nameMatch })
    if ($matches.Length -eq 0) { throw "No running process found matching '$nameMatch'" }
    if ($matches.Length -ne 1) { throw "Too many running processes found matching '$nameMatch'" }

    $processId = $matches[0].ProcessId
    $commandLine = $matches[0].CommandLine
    $executablePath = $matches[0].ExecutablePath

    function isRecognizedCommandLine($commandLine, $executablePath) {
        if ($commandLine -eq $executablePath) { return $true }

        # I can kinda understand why I see quotes around the filename:
        $withQuotes = '"' + $executablePath + '"'
        if ($commandLine -eq $withQuotes) { return $true }

        # But for some reason, I typically see a trailing space too (after the end-quote)
        if ($commandLine -eq "$withQuotes ") { return $true }
        return $false
    }

    # No support for command-line arguments currently - so just check there aren't any
    if (!(isRecognizedCommandLine $commandLine $executablePath)) {
        throw "Unsupported: There seem to be command line arguments: $commandLine"
    }

    Stop-Process -Id $processId -Force
    Start-Sleep -Milliseconds 100

    Invoke-Item $executablePath
}


# Test-PathIsUnder: Hopefully there's a more reliable, built-in way to do this now.
#   For now, this is what I've used. Returns whether '$path' is under '$root', at least in terms of looking at the paths themselves.
#   This doesn't require the paths to exist on the filesystem. Does NOT consider symlinks, hardlinks etc; the purpose of this
#   is for 'logical' structure, from the user-interface POV.
function Test-PathIsUnder([string] $path, [string] $root) {
    # Normalize
    $path = Join-Path $path ''
    $root = Join-Path $root ''

    # Compute
    $result = $path.StartsWith($root, [System.StringComparison]::InvariantCultureIgnoreCase)

    Write-Verbose "Test-PathIsUnder($path, $root) = $result"

    return $result
}

# Creates the given folder if needed, but only if its parent folder already exists
function New-Subfolder($path) {
    if (-not (Test-Path -PathType Container $path)) {
         $parent = Split-Path $path -parent
         if (-not (Test-Path -PathType Container $parent)) {
             throw "Not found: $parent"
         }

         New-Item -Type Directory $path | Out-Null
         $path = Resolve-Path $path
         if (Get-CurrentUserIsElevated) {
             icacls $path /setowner $env:username /q | Out-Null
             if (-not $?) {
                 throw ("Failed to set ownership on '$path'")
             }
         }
    }
}

# Creates the given folder if needed, recursively creating parent folders
function New-FolderAndParents($path) {
    if (-not (Test-Path -PathType Container $path)) {
         $parent = Split-Path $path -parent
         if ($parent -eq $path) { throw "Internal error" }

         if (-not (Test-Path -PathType Container $parent)) {
             New-FolderAndParents $parent
         }

         New-Subfolder $path
    }
}

. $PSScriptRoot\envDelta.ps1
. $PSScriptRoot\gitForkpoint.ps1

