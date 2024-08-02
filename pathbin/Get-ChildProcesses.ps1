param ($Id = $pid, [switch] $Recurse)

function getChildren($processId) {
  Get-WmiObject Win32_Process | Where-Object { $_.ParentProcessId -eq $processId }  
}


function getChildrenRecursive($processId) {
  $immediateChildren = @() + (getChildren $processId)
  $result = @() + $immediateChildren
  foreach ($child in $immediateChildren) {
    $result += (getChildrenRecursive $child.ProcessId)
  }

  return $result
}

if ($Recurse) { $result = getChildrenRecursive $Id } else { $result = getChildren $Id }
$result | Format-Table ProcessId, Name, ParentProcessId, CommandLine