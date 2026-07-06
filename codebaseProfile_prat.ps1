# For consumption by PratBase (Get-PratProject, Find-ProjectShortcut etc.)

# makeTestCommand: Uses [scriptblock]::Create() to work
# around Import-Scriptblock's closure limitation.
function makeTestCommand([string]$cmd) {
    [scriptblock]::Create(
        'param($project, [hashtable]$CommandParameters = @{})
        $paramsString = ($CommandParameters.GetEnumerator() | Sort-Object Key |
            ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
        if ($paramsString) { $paramsString = ": $paramsString" }
        "testCb: ' + $cmd + ': $($env:testEnvvar)$paramsString"'
    )
}

@{
    "." = @{
        repos = @{
            prat   = @{
                root   = $PSScriptRoot
                test   = "lib/Test-PratLayer.ps1"
                deploy = {
                    param($project, [hashtable]$CommandParameters = @{})
                    $force = [bool]($CommandParameters['Force'])
                    $script = Resolve-PratLibFile "lib/deployEnv.ps1"
                    pwsh -File $script -Force:$force
                }
            }
            testCb = @{
                root           = "pathbin/tests/testCb"
                cachedEnvDelta = "testCb_envDelta.ps1"
                build    = makeTestCommand 'build'
                test     = makeTestCommand 'test'
                deploy   = makeTestCommand 'deploy'
                prebuild = makeTestCommand 'prebuild'
                # Not a real project — its `test` returns a plain
                # string which would confuse aggregation code.
                excludeFromAggregation = $true
            }
        }
        shortcuts = @{
            # 'prat' shortcut (-> repo root) is implicit
            pauto    = "auto"
            pbin     = "pathbin"
            plog     = "auto/log"
            plib     = "lib"
            ptestrun = "auto/testRuns/last"
            pag      = "lib/agents"

            # Global shortcuts
            appdata   = $env:appdata
            desktop   = "$home/desktop"
            downloads = "$home/Downloads"
            startup   = "$env:appdata/Microsoft/Windows/Start Menu/Programs/Startup"
            hosts     = "$env:windir/system32/drivers/etc"
        }
    }
}
