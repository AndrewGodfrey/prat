# Dot-source this script to define some handy shortcuts.

#
# Directory navigation
#

function ..     {cd ../$Args}
function ...    {cd ../../$Args}
function ....   {cd ../../../$Args}
function .....  {cd ../../../../$Args}
function ...... {cd ../../../../../$Args}
function ~      {cd $env:userprofile\$Args}

# .SYNOPSIS
# Pushes or pops a directory
# 
# .DESCRIPTION
# With a parameter, this is 'pushd'. Without, it's 'popd'.
function p($Target) {
    if ($null -eq $Target) {
        popd
    } else {
        pushd $Target
    }
}

#
# 'dir' shortcuts
#

# Powershell defines an 'ls' alias, but it doesn't Format-Wide like unix. So this implementation is a bit closer:
#
# Why @args: Just "$args" doesn't work for named params - consider "w -directory". Here's a discussion: https://stackoverflow.com/questions/51219038/can-you-splat-positional-arguments-in-powershell
# Tab-completion still doesn't work, but "w -di" does.
function ls {(dir @args) | Format-Wide -AutoSize}

function ds { dir | sort -Property LastWriteTime }

# .SYNOPSIS
# Show the biggest n files in the directory.
function dirtop {
    param ([int] $n=10)
    dir | Sort-Object -Property Length -Descending | Select-Object -First $n
}


#
# Search
#

# .SYNOPSIS
# Find Recursive
# 
# .DESCRIPTION
#
# Searches source files in the current directory tree
# for the given string. Excludes Mercurial/Git hidden directories.
# 
# This is handy for searching from the current directory. But it lacks some features (that I use SlickEdit's search for when I need them):
# doesn't focus on source code files, and it does a single-threaded search.
#
# Can also pass other 'findstr' args like:
#   /C:"" literal search string
#   /I    case-insensitive
#   /M    only print filenames.
#   /R    regular expressions
#   /V    only print non-matching lines
function rf([switch] $IncludingBuiltFiles) {
    $p = $pwd.Path
    if ($IncludingBuiltFiles) { $ls = "lsr" } else { $ls = "lssr" }
    &$ls | findstr /f:/ /p $Args |
        ForEach-Object { if ($_.StartsWith($p, 'InvariantCultureIgnoreCase')) { "." + $_.Substring($p.Length) } else { $_ } }  # Convert paths to relative from $pwd
}

# .SYNOPSIS
# ls Source Recursive
# 
# .DESCRIPTION
#
# Enumerates source files in the current directory tree, excluding non-source cases like built files
function lssr {
    if ((up .git).Length -ne 0) {
        git ls-files
    } else {
        lsr
    }
}


# .SYNOPSIS
# ls Recursive
# 
# .DESCRIPTION
#
# Enumerates all files in the current directory tree, only excluding git/Mercurial directories
function lsr {
    dir -r * | ? {-not $_.PsIsContainer} | % { $_.FullName } | ? { $_ -notmatch "\\\.(hg|git)\\"}
}

# .SYNOPSIS
# Search path for executable files.
# 
# .DESCRIPTION
# I defined this because:
# 1. where.exe doesn't include .PS1 files
# 2. 'where' is a PowerShell keyword, making where.exe harder to access.
function wh {
    $pathextSave = $env:pathext
    $env:pathext = $env:pathext + ";.PS1"
    where.exe $Args
    $env:pathext = $pathextSave
}


#
# Other
#

# .SYNOPSIS
# Marks the current window as a 'playground', as a reminder to throw it away when I'm done
# 
# .DESCRIPTION
# For now, it just changes the window color.
# I use this for testing, e.g. dot-sourcing a file to play with its definitions.
function playground {
    pratSetWindowTitle "TEMP - playground"
    cmd /c color 47
}


# .SYNOPSIS
# Create a new empty text file. "New Item (of type) File".
function nif {
    New-Item -Type File $Args
}


