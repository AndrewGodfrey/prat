# .SYNOPSIS
# Compares the SHA256 hash of a file to a given hash.
#
# Alias: ch
param ($file, $hash=$(throw "need hash"))
(Get-FileHash -Algorithm SHA256 $file).Hash -eq $hash