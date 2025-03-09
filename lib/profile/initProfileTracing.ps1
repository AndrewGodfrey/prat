if (Test-Path function:pratProfile_trace) { return }

$pratProfile_shouldTrace = $false

if ($pratProfile_shouldTrace) {
    $pratProfile_prevDateStack = New-Object System.Collections.Stack
    $pratProfile_prevDateStack.Push((Get-Date))

    function pratProfile_trace {
        param ([ValidateSet("start", "done", "end")] [string] $type, [string] $msg)

        $now = Get-Date

        if ($type -eq "end") {
            if ($pratProfile_prevDateStack.Count -le 1) { 
                Write-Warning "pratProfile_trace: end without start" 
            } else {
                $pratProfile_prevDateStack.Pop() | Out-Null
            }
        }

        $indentLevel = $pratProfile_prevDateStack.Count - 1

        $delta = ($now - $pratProfile_prevDateStack.Peek()).TotalMilliseconds
        # Update previous timestamp
        $pratProfile_prevDateStack.Pop() | Out-Null
        $pratProfile_prevDateStack.Push($now)

        if ($type -eq "start") {
            $pratProfile_prevDateStack.Push($now)
        }

        $typeString = $type + (" " * (5 - $type.Length))
        $deltaString = [String]::Format("{0:F0}", $delta)
        $deltaString = $deltaString + "ms" + " " * (5 - $deltaString.Length)
        $indent = " " * (8 * $indentLevel)
        Write-Host -ForegroundColor DarkCyan " * $indent$deltaString $typeString`:  $msg"
    }
} else {
    function pratProfile_trace {}
}
