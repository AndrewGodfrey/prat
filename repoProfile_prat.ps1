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
            }
            testCb = @{
                root           = "pathbin/tests/testCb"
                cachedEnvDelta = "testCb_envDelta.ps1"
                build    = makeTestCommand 'build'
                test     = makeTestCommand 'test'
                deploy   = makeTestCommand 'deploy'
                prebuild = makeTestCommand 'prebuild'
            }
        }
        shortcuts = @{
            # 'prat' shortcut (-> repo root) is implicit
            pauto    = "auto"
            pbin     = "pathbin"
            plog     = "auto/log"
            plib     = "lib"
            ptestrun = "auto/testRuns/last"

            # Global shortcuts
            appdata   = $env:appdata
            desktop   = "$home/desktop"
            downloads = "$home/Downloads"
            startup   = "$env:appdata/Microsoft/Windows/Start Menu/Programs/Startup"
            hosts     = "$env:windir/system32/drivers/etc"
        }
    }
}
