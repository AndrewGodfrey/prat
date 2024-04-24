
# Set or create a registry key (expecting its parent to exist). Reports its actions & inactions to $stage.
function Install-RegistryKey($stage, [string] $path) {
    if (-not (Test-Path $path)) {
        $stage.OnChange()
        $parent = Split-Path $path -parent
        $leaf = Split-Path $path -leaf
        New-Item -Path $parent -Name $leaf -Force | Out-Null
    }
}

# Set or create one dword registry value. The key must exist. Reports its actions & inactions to $stage.
# For the default value, pass $null as $propertyName.
function Install-RegistryDwordValue($stage, [string] $path, $propertyName, [uint32] $newData) {
    $key = Get-Item -Path $path

    $property = $key.GetValue($propertyName)
    if (($property -eq $null) -or 
        ($key.GetValueKind($propertyName) -ne "DWord") -or
        ($property -ne $newData))
    {
        $stage.OnChange()
        if ($propertyName -eq $null) { $propertyName = "(Default)" }
        New-ItemProperty -Path $path -Name $propertyName -PropertyType DWord -Value $newData -Force | Out-Null
    }
}

# Set or create one string registry value. The parent key must exist. Reports its actions & inactions to $stage.
# For the default value, pass $null as $propertyName.
function Install-RegistryStringValue($stage, [string] $path, $propertyName, [string] $newData) {
    $key = Get-Item -Path $path
    $property = $key.GetValue($propertyName)
    if (($property -eq $null) -or 
        ($key.GetValueKind($propertyName) -ne "String") -or
        ($property -ne $newData))
    {
        $stage.OnChange()
        if ($propertyName -eq $null) { $propertyName = "(Default)" }
        New-ItemProperty -Path $path -Name $propertyName -PropertyType String -Value $newData -Force | Out-Null
    }
}

function areByteArraysEqual([byte[]] $a1, [byte[]] $a2) {
    return @(Compare-Object $a1 $a2 -SyncWindow 0).Length -eq 0
}

# Set or create one binary registry value. The parent key must exist. Reports its actions & inactions to $stage.
function Install-RegistryBinaryValue($stage, [string] $path, [string] $propertyName, [byte[]] $newData) {
    $key = Get-Item -Path $path
    $property = $key.GetValue($propertyName)
    if (($property -eq $null) -or 
        ($key.GetValueKind($propertyName) -ne "Binary") -or
        (-not (areByteArraysEqual $property $newData)))
    {
        $stage.OnChange()
        New-ItemProperty -Path $path -Name $propertyName -PropertyType Binary -Value $newData -Force | Out-Null
    }
}





