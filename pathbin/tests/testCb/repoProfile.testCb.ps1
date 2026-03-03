# For consumption by Get-PratProject / Get-CodebaseTables
@{
    repos = @{
        testCb = @{
            root           = $PSScriptRoot
            cachedEnvDelta = "testCb_envDelta.ps1"
        }
    }
    # 'testCb' shortcut (-> repo root) is implicit
}
