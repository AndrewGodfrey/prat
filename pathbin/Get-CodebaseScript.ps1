# .SYNOPSIS
# Looks for a codebase-specific command script
#
# Scripts that use this search $env:path, so that it can be overridden by putting another
# implementation earlier in $env:path.
# 
# .RETURNS
# Can be either:
#   A scriptblock:  Code to execute
#   A string:       a full-path filename to a script to run
#
# The first param passed to the scriptblock/script, is $project, the repo profile entry for this codebase.
# For other params, see the implementations of Build-Codebase, Test-Codebase and Deploy-Codebase.
param(
    [ValidateSet("prebuild", "build", "test", "deploy")] [string] $CommandName,
    [string] $codebase
)

switch ($codebase) {    
    "prat" {
        switch ($CommandName) {
            "build"  { return {Build-Prat} }
            "test"   { return {
                param([hashtable] $CommandParameters = @{})
                $repoRoot = if ($CommandParameters.ContainsKey('RepoRoot')) { $CommandParameters['RepoRoot'] } else { "$home/prat" }
                $pathToTest = &"$home/prat/lib/Resolve-TestFocus" $CommandParameters['Focus'] $repoRoot
                Invoke-PesterWithCodeCoverage `
                    -NoCoverage:$CommandParameters['NoCoverage'] `
                    -PathToTest $pathToTest `
                    -RepoRoot $repoRoot `
                    -Debugging:$CommandParameters['Debugging'] `
                    -OutputDir $CommandParameters['OutputDir'] `
                    -IncludeIntegrationTests:$CommandParameters['IncludeIntegrationTests']
            } }
            "deploy" { return {
                param([hashtable]$CommandParameters = @{})
                Deploy-Prat -Force:$CommandParameters['Force']
            } }
        }
    }
    "testCb" {
        return {
            param([hashtable]$CommandParameters = @{})
            $paramsString = ($CommandParameters.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
            if ($paramsString) { $paramsString = ": $paramsString" }
            "testCb: $($CommandName): $($env:testEnvvar)$paramsString"
        }.GetNewClosure()
    }    
}

return $null
