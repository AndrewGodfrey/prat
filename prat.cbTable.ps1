# For consumption by Get-CodebaseTable
@{
    prat = @{ 
        howToBuild = "Build-Prat"; howToTest = "Invoke-Pester"; howToDeploy = "Deploy-Prat" 
        shortcuts = @{
            pr = ""
            pa = "auto"
            plog = "auto/log"
            plib = "lib"
        }
    }
}

