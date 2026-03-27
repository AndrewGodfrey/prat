Write-Host "Machine path:"
[System.Environment]::GetEnvironmentVariable("PATH", "Machine") -split ';'
Write-Host "`nUser path:"
[System.Environment]::GetEnvironmentVariable("PATH", "User") -split ';'
Write-Host "`nEnv path:"
$env:PATH -split ';'

