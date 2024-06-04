# Searches the current directory and 'upwards', for a given pattern.
# Shows matches for the first directory that has matches.
#
# Examples:
#   up *.sln
#   up app.config
param ($pattern)
$results = &$PSScriptRoot/../lib/Get-ContainingItem -Multiple $pattern $pwd
if ($null -ne $results) {
    echo $results.FullName
}

