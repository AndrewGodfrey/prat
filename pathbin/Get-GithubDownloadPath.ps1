# Given a file, finds its direct 'raw' url on github.
# Could be extended to other online repos that support raw paths (not all do).
#
# Don't overuse this. Its purpose is 'bootstrapping'. I can think of two kinds:
# 1. Prat installation currently uses a raw url to get Install-Prat.ps1.
# 2. While this is fragile: If you want to point someone at a standalone script in a repo without
#    them having to install the whole repo. It's fragile because the script could later be updated to depend on
#    other things in the repo. But it makes sense for tiny scripts - say Get-ErrorStatuses.ps1, or Lock-FileExclusively.ps1.
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
