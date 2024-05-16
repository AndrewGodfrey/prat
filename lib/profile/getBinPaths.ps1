$result = "";

$result += ";" + (Resolve-Path "$PSScriptRoot\..\..\pathbin").Path 
$result += ";$home\prat\auto\pathbin"

return $result

