# For consumption by PratBase (Get-PratProject, Find-ProjectShortcut etc.)
@{
    "." = @{
        repos = @{
            prat   = @{
                root   = $PSScriptRoot
            }
            testCb = @{
                root           = "pathbin/tests/testCb"
                cachedEnvDelta = "testCb_envDelta.ps1"
                build    = {
                    param($project, [hashtable]$CommandParameters = @{})
                    $paramsString = ($CommandParameters.GetEnumerator() | Sort-Object Key |
                        ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
                    if ($paramsString) { $paramsString = ": $paramsString" }
                    "testCb: build: $($env:testEnvvar)$paramsString"
                }
                test     = {
                    param($project, [hashtable]$CommandParameters = @{})
                    $paramsString = ($CommandParameters.GetEnumerator() | Sort-Object Key |
                        ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
                    if ($paramsString) { $paramsString = ": $paramsString" }
                    "testCb: test: $($env:testEnvvar)$paramsString"
                }
                deploy   = {
                    param($project, [hashtable]$CommandParameters = @{})
                    $paramsString = ($CommandParameters.GetEnumerator() | Sort-Object Key |
                        ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
                    if ($paramsString) { $paramsString = ": $paramsString" }
                    "testCb: deploy: $($env:testEnvvar)$paramsString"
                }
                prebuild = {
                    param($project, [hashtable]$CommandParameters = @{})
                    $paramsString = ($CommandParameters.GetEnumerator() | Sort-Object Key |
                        ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
                    if ($paramsString) { $paramsString = ": $paramsString" }
                    "testCb: prebuild: $($env:testEnvvar)$paramsString"
                }
            }
        }
        shortcuts = @{
            # 'prat' shortcut (-> repo root) is implicit
            pauto    = "auto"
            pbin     = "pathbin"
            plog     = "auto/log"
            plib     = "lib"
            ptestrun = "auto/testRuns/last"
        }
    }
}
