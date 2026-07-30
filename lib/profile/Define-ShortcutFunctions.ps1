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

function ds { dir @args | sort -Property LastWriteTime }

# .SYNOPSIS
# Show the biggest n files in the directory.
function dirtop {
    param ([int] $n=10)
    dir | Sort-Object -Property Length -Descending | Select-Object -First $n
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


