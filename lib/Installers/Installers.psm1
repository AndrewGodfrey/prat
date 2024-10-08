# 'Installers' are functions which can 'install' various resources for the current user, and by 'install' I specifically mean these steps:
# 
# 1. do a quick check to see if it's already present. (Or if there's no reliable quick check, look up in a database)
# 2. if installation is needed:
#    2.1 Notify the user about the change (via an interface)
#    2.2 Install the resource
#
# .DESCRIPTION
#   $installationTracker = $null
#   try {
#      $installationTracker = Start-Installation "<installer name>"
#      [ ... installation steps ... ]
#   } catch {
#       if ($null -ne $installationTracker) { $installationTracker.ReportErrorContext($error[0]) }
#       throw
#   } finally {
#      if ($null -ne $installationTracker) { $installationTracker.StopInstallation() }
#   }
#
# A well-formed installation step looks like this:
#
#   $stage = $installationTracker.StartStage("<name of stage>")
#      [... installation steps that call $stage.OnChange() whenever they decide to install/update something ...]
#   $installationTracker.EndStage($stage)
#
# In more detail, that looks like this:
#
#   $stage = $installationTracker.StartStage("<name of stage>")
#     if (<we need to update thing1>) {
#       $stage.OnChange()
#       <update thing1> 
#     }
#     if (<we need to update thing2>)
#     {
#       $stage.OnChange()
#       <update thing2>
#     }
#     [... etc ...]
#   $installationTracker.EndStage($stage)
#
#   You can also optionally use $stage.SetSubstage("<substage name>"). This is useful for
#   - progress reporting for substages that take a long time to install
#   - providing context for a failure (provided you use ReportErrorContext as shown above)
#   - providing context on warnings emitted using $stage.WriteWarning()

class InstallationTracker {
    hidden [InstallationStage] $currentStage = $null
    hidden [System.Threading.Mutex] $mutex = $null
    hidden [string] $installerName

    hidden [string] $installationDatabaseLocation
    hidden [bool] $forceReinstallation = $false

    InstallationTracker([string] $installerName, [string] $installationDatabaseLocation, [bool] $Force) {
        $this.installerName = $installerName
        $this.installationDatabaseLocation = $installationDatabaseLocation
        $this.forceReinstallation = $Force

        $createdNew = $False
        $m = New-Object -TypeName System.Threading.Mutex($true, "Start_Installation_$installerName", [ref]$createdNew)
        if (!$createdNew) { throw "Another '$installerName' installation is in progress" }
        $this.mutex = $m
    }

    [Void] StopInstallation() {
        # Avoid things which might throw. It's used in a 'finally' and could hide some other exception
        $this.currentStage = $null
        if ($null -ne $this.mutex) {
            $this.mutex.Close()
            $this.mutex = $null
        }
    }

    [Void] CheckEmptyStage() {
        if ($null -ne $this.currentStage) { throw "Previous stage '$($this.currentStage.Name)' forgot to call EndStage()" }
    }

    [InstallationStage] StartStage([string] $stageName) {
        $this.CheckEmptyStage()

        $this.currentStage = [InstallationStage]::new($this, $stageName)
        return $this.currentStage
    }

    [Void] EndStage([InstallationStage] $stage) {
        if ($this.currentStage -ne $stage) { throw "Internal error" }
        $this.currentStage = $null
    }

    [Void] UpdateProgress([string] $subStage) {
        $operationName = ""
        if ($null -ne $this.currentStage)
        {
            $operationName = $this.currentStage.Name
            if ($subStage -ne "") {
                $operationName += " - " + $subStage
            }
        }
        Write-Progress $this.installerName -CurrentOperation $operationName
    }

    [bool] GetIsStepComplete($stepId, $version) {
        if ($this.forceReinstallation) { return $false }
        return (Test-InstalledItemVersion $this.installationDatabaseLocation $stepId $version)
    }

    # Mark the given step as complete
    [Void] SetStepComplete($stepId, $version) {
        Set-InstalledItemVersion $this.installationDatabaseLocation $stepId $version
    }

    [Void] ClearStep($stepId) {
        Remove-InstalledItem $this.installationDatabaseLocation $stepId
    }

    [Void] ReportErrorContext($e) {
        if ($null -ne $this.currentStage) {
            $sc = $this.currentStage.GetPrintableStageContext()
            $psStack = $e.ScriptStackTrace
            Write-Error @"
Error during stage $($sc):
    $e
$psStack
"@
        }
    }
}

class InstallationStage {
    hidden [InstallationTracker] $parent
    hidden [bool] $stageHasMadeChanges = $False  # Whether the entire stage has made any changes so far
    hidden [bool] $throwOnChange = $False  # Useful for debugging unexpected changes

    [string] $Name
    [string] $CurrentSubStage = ""        # For progress reporting and error context (but not used for regular console output - too verbose).


    InstallationStage([InstallationTracker] $parent, [string] $stageName) {
        $this.parent = $parent
        $this.Name = $stageName
        $this.parent.UpdateProgress("")
    }

    [Void] EnableThrowOnChange() {
        $this.throwOnChange = $true
    }

    [Void] SetSubstage([string] $subStage) {
        $this.parent.UpdateProgress($subStage)
        $this.CurrentSubStage = $subStage
    }

    [string] GetPrintableStageContext() {
        $n = $this.Name
        $substage = $this.CurrentSubstage
        if ($substage -ne "") {
            $n += "', substage '$substage"
        }
        return "stage '$n'"
    }

    [Void] WriteWarning([string] $message) {
        $sc = $this.GetPrintableStageContext()
        Write-Host -ForegroundColor Yellow "warning: $($sc): $message"
    }

    # Use for migration steps - i.e. cleanup that can be removed once the installer has been run on every machine.
    # In theory, the script could keep track of which machines have run a given migration step. But for now, it's manual.
    [Void] NoteMigrationStep([datetime] $dateAdded) {
        $now = Get-Date
        $age = ($now - $dateAdded).Days

        if ($age -gt 30) {
            $this.WriteWarning("Old migration step found - consider removing ($age days old)")
        }
    }
    [Void] OnChange() {
        if ($this.throwOnChange) { throw "Unexpected change (ThrowOnChange was enabled)" }

        if ($this.stageHasMadeChanges) { return } # Only report the first change
        $this.stageHasMadeChanges = $True
        Write-Host -ForegroundColor Cyan "updating: $($this.Name)"
    }

    # Returns true if OnChange() was ever called during this stage. i.e. false means this stage was a no-op.
    [bool] DidUpdate() {
        return $this.stageHasMadeChanges
    }

    # 'installation steps': Methods for managing steps tracked in the installation database, including manual steps.
    # 
    # Examples for $stepIdAndVersion:
    #   "Shortcuts/DE/props:1.1"
    #   "gitrepos/llamacpp/VSDevCmd" (version 1.0 is implied in this case)

    hidden [Object[]] ParseStepIdAndVersion([string] $stepIdAndVersion) {
        if (!($stepIdAndVersion.Contains(":"))) { return ($stepIdAndVersion, "1.0") }
        $split = $stepIdAndVersion -split ":",2
        return ($split[0], $split[1])
    }

    # Return true if the given step has been done (false if it was skipped / not reached yet)
    #
    # Note: Throws if the installed version is GREATER than expected. We expect version numbers to always go up.
    #       For a downgrade, do a migration step or something - that's an error-prone situation that deserves thought.
    [bool] GetIsStepComplete($stepIdAndVersion) {
        ($stepId, $version) = $this.ParseStepIdAndVersion($stepIdAndVersion)
        return $this.parent.GetIsStepComplete($stepId, $version)
    }

    # Mark the given step as complete
    [Void] SetStepComplete($stepIdAndVersion) {
        ($stepId, $version) = $this.ParseStepIdAndVersion($stepIdAndVersion)
        $this.parent.SetStepComplete($stepId, $version)
    }

    # If the given manual step hasn't been completed,
    # mark the stage as changed, emit the given manual instructions, and ask the user if they skipped it or did it.
    # If they say they did it, mark it as complete.
    [Void] EnsureManualStep($stepIdAndVersion, $instructions) {
        if (-not ($this.GetIsStepComplete($stepIdAndVersion))) {
            $this.OnChange()
            ($stepId, $version) = $this.ParseStepIdAndVersion($stepIdAndVersion)

            Write-Host -F Red ($stepId + ": $instructions")
            Write-Host -F Blue "Hit 'Enter' to skip, or type 'd' when done"
            $result = Read-Host

            if ($result -eq "d") {
                $this.SetStepComplete($stepIdAndVersion)
            }
        }
    }

    [Void] ClearManualStep($stepId) {
        $this.parent.ClearStep($stepId)
    }
}


# .SYNOPSIS
# Begins an installation script (for the current user). Responsibilities:
#
# 1. Ensure only 1 instance of this installation script is running at a time. (But does NOT detect e.g. Add/Remove programs running).
# 2. Report status using Write-Host:
#    - Emit to the console when an installation step does something, but stay quiet if there are no changes.
#    - If the step does do something, indicate that to the user (succinctly)
# 3. Report progress using Write-Progress.
# 
# .PARAMETER InstallerName
# This is used:
#   1. as part of the name of the mutex used to guard against simultaneous installations. So, each separate $installerName is an independent installer.
#   2. in the progress UI, to identify the installer to the user
#
# .PARAMETER InstallationDatabaseLocation
# This is a folder that will keep track of which installation steps can be skipped as they have already been successfully completed.
# This is typically used only for steps that lack a way to quickly check for past completion.
# 
# .NOTES
# Performance: That 'check for install' action needs to be very quick. If it isn't, consider replacing it with a quick check. 
# 
# One option is to use the functions in installedItemDb.ps1.
# - the downside is you need to increment a version number when you change the code, so this works best for things that change very rarely
# - but consider changing the design of whatever it is to reduce the rate of change. For example: 
#   To install a file association where the executable path includes a version number: create a stub script with a more stable location, 
#   so that updating the stub script doesn't require updating the file association.
#
# Composition:
# - Stages *can't nest*. Maybe that's worth exploring later, but I haven't felt a need for it. OTOH:
# - You can pass $stage to another script that can install a thing. This is an important way to reduce complexity.
# 
# The resulting Write-Host output is:
# - If the stage is up-to-date, nothing is emitted.
# - Otherwise, we'll emit "updating: <stageName>" - just once.
#    
# Error handling:
#   - Note that "$stage.End()" isn't called in a try...catch...finally. (Unlike the creation of the InstallationTracker itself).
#     This design follows/assumes the "quit on error; manual retry" model - if the installation script doesn't emit "OK" at the end then it
#     needs to be rerun. On error, we don't want $stage.End() to run because it would give the wrong impression ... the stage never did finish.

function Start-Installation([Parameter(Position=0)] [string] $InstallerName, [Parameter(Position=-1)] [string] $InstallationDatabaseLocation, [switch] $Force) {
    return [InstallationTracker]::new($InstallerName, $InstallationDatabaseLocation, $Force)
}

. $PSScriptRoot\instFilesAndFolders.ps1

. $PSScriptRoot\instRegistry.ps1

. $PSScriptRoot\instPackages.ps1

. $PSScriptRoot\instWingetPackages.ps1

. $PSScriptRoot\instNugetPackages.ps1

. $PSScriptRoot\installedItemDb.ps1

. $PSScriptRoot\instWindowsCustomization.ps1

. $PSScriptRoot\instWindowsShortcut.ps1

. $PSScriptRoot\instCustomBrowserHomePage.ps1

. $PSScriptRoot\instPsProfile.ps1

