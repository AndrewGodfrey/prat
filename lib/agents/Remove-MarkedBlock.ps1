param(
    [Parameter(Mandatory)][string]$Path,
    [string]$From = '<!-- DELETE_FROM_HERE -->',
    [string]$To   = '<!-- DELETE_TO_HERE -->'
)

$c = Get-Content $Path -Raw
$a = $c.IndexOf($From)
$b = $c.IndexOf($To)

if ($a -lt 0) { Write-Error "Start marker not found: $From"; exit 1 }
if ($b -lt 0) { Write-Error "End marker not found: $To";   exit 1 }
if ($b -le $a) { Write-Error "End marker appears before start marker"; exit 1 }

$b += $To.Length
if ($c[$b] -eq "`r") { $b++ }
if ($c[$b] -eq "`n") { $b++ }

Set-Content $Path ($c.Substring(0, $a) + $c.Substring($b)) -NoNewline -Encoding UTF8
Write-Host "Removed block from $Path"
