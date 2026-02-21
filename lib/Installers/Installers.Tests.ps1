using module .\Installers.psd1

Describe "InstallationTracker" {
    BeforeEach {
        $script:installerName = [guid]::NewGuid().ToString()
        $script:dbLocation = "TestDrive:\instDb"
        Mock -ModuleName Installers Write-Progress {}
        $script:tracker = Start-Installation $installerName -InstallationDatabaseLocation $dbLocation
    }
    AfterEach {
        if ($null -ne $script:tracker) { $script:tracker.StopInstallation() }
    }

    It "Throws if another installation with the same name is already in progress" {
        { Start-Installation $installerName -InstallationDatabaseLocation $dbLocation } | Should -Throw "*installation is in progress*"
    }

    It "Allows a new installation after StopInstallation" {
        $tracker.StopInstallation()
        $script:tracker = Start-Installation $installerName -InstallationDatabaseLocation $dbLocation
    }

    It "StartStage throws if previous stage was not ended" {
        $stage = $tracker.StartStage("stage1")
        { $tracker.StartStage("stage2") } | Should -Throw "*forgot to call EndStage*"
        $tracker.EndStage($stage)
    }

    It "EndStage throws if given a different stage than was started" {
        $stage1 = $tracker.StartStage("stage1")
        $stage2 = [InstallationStage]::new($tracker, "stage2")
        { $tracker.EndStage($stage2) } | Should -Throw "*Internal error*"
        $tracker.EndStage($stage1)
    }

    It "ReportErrorContext includes stage name" {
        $stage = $tracker.StartStage("my stage")
        try { throw "test error" } catch { $err = $_ }
        Mock -ModuleName Installers Write-Error {}
        $tracker.ReportErrorContext($err)
        Should -Invoke -ModuleName Installers -CommandName Write-Error -Times 1 -ParameterFilter { $Message -match "my stage" }
        $tracker.EndStage($stage)
    }
}

Describe "InstallationStage" {
    BeforeEach {
        $script:installerName = [guid]::NewGuid().ToString()
        $script:tracker = Start-Installation $installerName -InstallationDatabaseLocation "TestDrive:\stepDb"
        Mock -ModuleName Installers Write-Progress {}
        Mock -ModuleName Installers Write-Host {}
        $script:stage = $tracker.StartStage("test stage")
    }
    AfterEach {
        try { $tracker.EndStage($stage) } catch {}
        $tracker.StopInstallation()
    }

    It "DidUpdate returns false before OnChange" {
        $stage.DidUpdate() | Should -Be $false
    }

    It "OnChange sets DidUpdate to true" {
        $stage.OnChange()
        $stage.DidUpdate() | Should -Be $true
    }

    It "OnChange writes 'updating: <name>' to host" {
        $stage.OnChange()
        Should -Invoke -ModuleName Installers -CommandName Write-Host -Times 1 -ParameterFilter { $Object -eq "updating: test stage" }
    }

    It "OnChange only reports first change" {
        $stage.OnChange()
        $stage.OnChange()
        $stage.OnChange()
        Should -Invoke -ModuleName Installers -CommandName Write-Host -Times 1
    }

    It "EnableThrowOnChange makes OnChange throw" {
        $stage.EnableThrowOnChange()
        { $stage.OnChange() } | Should -Throw "*Unexpected change*"
    }

    It "GetPrintableStageContext returns stage name" {
        $stage.GetPrintableStageContext() | Should -Be "stage 'test stage'"
    }

    It "GetPrintableStageContext includes substage when set" {
        $stage.SetSubstage("my substage")
        $stage.GetPrintableStageContext() | Should -Be "stage 'test stage', substage 'my substage'"
    }

    It "NoteMigrationStep warns if step is older than 30 days" {
        $oldDate = (Get-Date).AddDays(-31)
        $stage.NoteMigrationStep($oldDate)
        Should -Invoke -ModuleName Installers -CommandName Write-Host -Times 1 -ParameterFilter { $Object -match "Old migration step" }
    }

    It "NoteMigrationStep does not warn if step is recent" {
        $recentDate = (Get-Date).AddDays(-1)
        $stage.NoteMigrationStep($recentDate)
        Should -Invoke -ModuleName Installers -CommandName Write-Host -Times 0
    }

    It "GetIsStepComplete returns false for a new step" {
        $stage.GetIsStepComplete("newstep") | Should -Be $false
    }

    It "SetStepComplete then GetIsStepComplete returns true" {
        $stage.SetStepComplete("donestep")
        $stage.GetIsStepComplete("donestep") | Should -Be $true
    }

    It "Step ID without version colon defaults to version 1.0" {
        $stage.SetStepComplete("versionstep")
        $stage.GetIsStepComplete("versionstep:1.0") | Should -Be $true
    }

    It "Step ID with explicit version is parsed correctly" {
        $stage.SetStepComplete("versionstep2:2.0")
        $stage.GetIsStepComplete("versionstep2:2.0") | Should -Be $true
    }

    It "EnsureManualStep skips when step is already complete" {
        $stage.SetStepComplete("manualstep1")
        $stage.EnsureManualStep("manualstep1", "do the thing")
        $stage.DidUpdate() | Should -Be $false
        Should -Invoke -ModuleName Installers -CommandName Write-Host -Times 0
    }

    It "EnsureManualStep calls OnChange and prompts when step is not complete" {
        Mock -ModuleName Installers Read-Host { return "" }
        $stage.EnsureManualStep("manualstep2", "do the thing")
        $stage.DidUpdate() | Should -Be $true
        $stage.GetIsStepComplete("manualstep2") | Should -Be $false
    }

    It "EnsureManualStep marks step complete when user types 'd'" {
        Mock -ModuleName Installers Read-Host { return "d" }
        $stage.EnsureManualStep("manualstep3", "do the thing")
        $stage.DidUpdate() | Should -Be $true
        $stage.GetIsStepComplete("manualstep3") | Should -Be $true
    }

    It "EnsureManualStep leaves step incomplete when user types Enter" {
        Mock -ModuleName Installers Read-Host { return "" }
        $stage.EnsureManualStep("manualstep4", "do the thing")
        $stage.DidUpdate() | Should -Be $true
        $stage.GetIsStepComplete("manualstep4") | Should -Be $false
    }

    It "ClearManualStep returns the step to being incomplete" {
        Mock -ModuleName Installers Read-Host { return "d" }
        $stage.EnsureManualStep("manualstep5", "do the thing")
        $tracker.EndStage($stage)
        $stage = $tracker.StartStage("test stage 2")
        $stage.DidUpdate() | Should -Be $false

        $stage.ClearManualStep("manualstep5")

        $stage.DidUpdate() | Should -Be $true
        $stage.GetIsStepComplete("manualstep5") | Should -Be $false
    }
}
