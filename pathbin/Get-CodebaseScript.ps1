# .SYNOPSIS
# Looks for a codebase-specific action script
#
# Scripts that use this search $env:path, so that it can be overridden by putting another
# implementation earlier in $env:path.
# 
# .RETURNS
# Can be either:
#   A scriptblock:  Code to execute
#   A string:       a full-path filename to a script to run
#
# The first param passed to the scriptblock/script, is $cbt, the codebase table for this codebase.
# For other params, see the implementations of Build-Codebase, Test-Codebase and Deploy-Codebase.
param(
    [ValidateSet("prebuild", "build", "test", "deploy")] [string] $action,
    [string] $codebase,
    [switch] $Force
)

switch ($codebase) {    
    "prat" {
        switch ($action) {
            "build"  { return {Build-Prat} }
            "test"   { return { 
                param([hashtable] $CommandSwitches = @{})
                Test-Prat -CodeCoverage:$CommandSwitches['CodeCoverage']} 
            }
            "deploy" { return {Deploy-Prat -Force:$Force} }
        }
    }
    "testCb" {
        if ("prebuild", "build", "test", "deploy" -contains $action) { return {echo "testCb: $($action): $($env:testEnvvar)"} }
        throw "Unrecognized action: $action"
    }
}

return $null
