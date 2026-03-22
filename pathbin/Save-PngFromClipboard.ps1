param($path = ".")

function accumulateTryPath([ref] $path, $nextPath) {
    if ($null -eq $path.Value) {
        if (!(Test-Path $nextPath)) {
            $path.Value = $nextPath
        }
    }
}

$destFile = $null
if (Test-Path -PathType Container $path) {
    accumulateTryPath ([ref] $destFile) "$path/image.png"
    foreach ($n in 1..50) {
        accumulateTryPath ([ref] $destFile) "$path/image$n.png"
    }
} else {
    if ($path.Endswith(".png")) {
        accumulateTryPath ([ref] $destFile) "$path"
    }
    accumulateTryPath ([ref] $destFile) "$path.png"
    foreach ($n in 1..50) {
        accumulateTryPath ([ref] $destFile) "$path$n.png"
    }
}
if ($null -eq $destFile) {
    Write-Error "Couldn't find a filename to save to given '$path'"
    return
}

Add-Type -AssemblyName System.Windows.Forms
$image = [System.Windows.Forms.Clipboard]::GetImage()
if ($null -eq $image) {
    Write-Error "Failed to load image from clipboard"
    return
}
$image.Save($destFile, [System.Drawing.Imaging.ImageFormat]::Png)
echo "Saved to: $destFile"