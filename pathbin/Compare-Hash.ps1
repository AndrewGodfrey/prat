# Compare-Hash (alias: ch)
param ($file, $hash=$(throw "need hash"))
(Get-FileHash $file).Hash -eq $hash