param ($file)
if (!(Test-Path $file)) { throw "Not found: $file" }

$originUrl = (git remote get-url origin)  # e.g. https://github.com/AndrewGodfrey/prat.git
if (!$?) { throw }
if ($originUrl -notmatch '^https://github.com/') { throw "Not implemented: Only implemented for github urls so far" }

$originUrl = $originUrl -replace '\.git$', ''

$relPath = (git ls-files $file --full-name)
if (!$?) { throw }

$branch = (git branch --show-current)
if (!$?) { throw }

# e.g. https://github.com/AndrewGodfrey/prat/raw/main/pathbin/Get-TextFileEncoding.ps1
echo "$originUrl/raw/$branch/$relPath"
