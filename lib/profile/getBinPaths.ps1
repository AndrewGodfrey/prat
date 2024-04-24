$result = "";

$result += ";" + (Resolve-Path "$PSScriptRoot\..\..\pathbin").Path 

return $result

