# .SYNOPSIS
# Convert the given number to hexadecimal
#
# Alias: hex
param([long] $number)

"0x"+[Convert]::ToString($number, 16)


