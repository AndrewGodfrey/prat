# .SYNOPSIS
# Invoke-InlineCommandOnHost (alias: on)
# A shorter version of "Invoke-Command -HostName <foo> -ScriptBlock { <script> }".
# Invokes the given command on a remote host, using SSH remoting.
#
# You can alternatively pass it a scriptblock, needed if you want to use "$using:foo" or multiple statements.
#
# .EXAMPLE
# on myHost echo "Hello, world!"
# .EXAMPLE
# $remoteProcesses = on myHost Get-Process 
# .EXAMPLE
# on myHost {echo "hi"; echo "there"}
# .EXAMPLE
# $foo = "Hello, world!"
# on myHost {echo "$using:foo"}
param(
    [ArgumentCompleter(
    {
        param($cmd, $param, $wordToComplete)
        [array] $validValues = @() + (Get-MySshHosts)
        $validValues -like "$wordToComplete*"
    }
    )]
    $HostName, 
    [Parameter(ValueFromRemainingArguments=$true)] [object[]] $moreArgs
)
if (($moreArgs.Count -eq 1) -and ($moreArgs[0] -is [scriptblock])) {
    Invoke-Command -HostName $HostName -ScriptBlock $moreArgs[0]
} else {
    Invoke-Command -HostName $HostName -ScriptBlock { Invoke-Expression ($using:moreArgs -join ' ') }
}