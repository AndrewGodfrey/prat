# For consumption by Get-PratRepo / Get-CodebaseTables
@{
    repos = @{
        prat = @{ root = $PSScriptRoot }
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
