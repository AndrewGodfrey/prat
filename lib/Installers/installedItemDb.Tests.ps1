BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe "getCurrentSchemaVersion" {
    It "ReturnsVersionNumber" {
        $result = getCurrentSchemaVersion

        $result | Should -BeOfType String
        $resultAsVersion = [System.Version] $result
        $resultAsVersion | Should -Not -BeNull
        $minVersion = [System.Version] "1.0"
        $resultAsVersion -lt $minVersion | Should -BeFalse
    }
}

Describe "checkSchemaVersion" {
    BeforeEach {
        Mock getCurrentSchemaVersion { "2.1" }
        Mock getSchemaVersionFile { return "$dbLocation\schemaVersionFile" }
        Mock Get-Content { 
            if ($Path -ne "dbLocation\schemaVersionFile") { throw "Unexpected: $Path" }
            "2.1"
        }
    }
    It "VerifiesSilently" {
        checkSchemaVersion "dbLocation" | Should -Be $null
    }
    It "ThrowsWhenMismatch" {
        Mock getCurrentSchemaVersion { "2.2" }
        {checkSchemaVersion "dbLocation"} | Should -Throw "Schema version mismatch. Expected: '2.2'  Actual: '2.1'"
    }
}

Describe "getStateFilePath" {
    It "Concatenates" {
        getStateFilePath "db" "id" | Should -Be "db\id.txt"
    }
    It "ThrowsWhenInvalidIdChars" {
        {getStateFilePath "db" "#a"} | Should -Throw "Unsupported format for itemId '#a'. Use only alphanumeric, underscore and slash; first char an alphanumeric."
    }
}

Describe "getForkpointCacheStateFilePath" {
    It "Concatenates" {
        getForkpointCacheStateFilePath "db" "id_" | Should -Be "db\_forkpointCache\id_.ps1"
    }
    It "ThrowsWhenInvalidIdChars" {
        {getForkpointCacheStateFilePath "db" "_a"} | Should -Throw "Unsupported format for itemId '_a'. Use only alphanumeric, underscore and slash; first char an alphanumeric."
    }
}

Describe "Test-InstalledItemVersion" {
    BeforeEach {
        Mock Get-InstalledItemVersion {"9.7"}
    }
    It "ReturnsTrueWhenVersionsMatch" {
        Test-InstalledItemVersion $dbLocation "item" "9.7" | Should -Be $true
    }
    It "ReturnsFalseWhenExpectedVersionNewer" {
        Test-InstalledItemVersion $dbLocation "item" "10.1" | Should -Be $false
    }
    It "ReturnsFalseWhenNoInstalledVersion" {
        Mock Get-InstalledItemVersion { $null }
        Test-InstalledItemVersion $dbLocation "item" "10.1" | Should -Be $false
    }
    It "ThrowsWhenExpectedVersionOlder" {
        {Test-InstalledItemVersion $dbLocation "item" "8.0"} | Should -Throw "Unexpected: item: Current version is newer: 9.7 > 8.0"
    }
}

Describe "TestsUsingTestDrive" {
    BeforeEach {
        $dbLocation = "TestDrive:\installedItemDb.Tests.ps1"
        mkdir $dbLocation | Out-Null
    }
    AfterEach {
        Remove-Item -Recurse $dbLocation | Out-Null
    }
    Context "Get-InstalledItemVersion" {
        It "ReturnsStateFileContents" {
            Mock checkSchemaVersion {}
            New-Item -Path "$dbLocation\item.txt" -ItemType File -Value "9.7" | Out-Null
            
            Get-InstalledItemVersion $dbLocation "item" | Should -Be "9.7"
        }
        It "ReturnsNullWhenDbLocationDoesNotExist" {
            Get-InstalledItemVersion "$dbLocation\notExist" "id" | Should -BeNull
        }
        It "ReturnsNullWhenItemNotInstalled" {
            Mock checkSchemaVersion {}
            Test-Path $dbLocation | Should -BeTrue

            Get-InstalledItemVersion $dbLocation "idNotExist" | Should -BeNull
        }
    }
    Context "Set-InstalledItemVersion" {
        It "SetsStateFileContents" {
            Mock checkSchemaVersion {}
            
            Set-InstalledItemVersion $dbLocation "parent/item" "9.2.1"

            Test-Path "$dbLocation\parent\item.txt" | Should -BeTrue
            Get-Content "$dbLocation\parent\item.txt" | Should -Be "9.2.1"
        }
    }
    Context "Remove-InstalledItem" {
        It "Removes" {
            Mock checkSchemaVersion {}
            Set-InstalledItemVersion $dbLocation "parent/item" "9.2.1"
            Test-Path "$dbLocation\parent\item.txt" | Should -BeTrue

            Remove-InstalledItem $dbLocation "parent/item"

            Test-Path "$dbLocation\parent\item.txt" | Should -BeFalse
            Test-Path "$dbLocation\parent" | Should -BeTrue # It doesn't fully clean up
        }
    }
    Context "ensureDb" {
        It "CreatesFolderAndSchemaVersionFile" {
            Mock getCurrentSchemaVersion {"5.5"}
            $db = "$dbLocation\notExist2"
            Test-Path $db | Should -BeFalse

            ensureDb $db

            Test-Path $db | Should -BeTrue
            Get-Content "$db\installationDb.schemaVersion.txt" | Should -Be "5.5"
        }
        It "DoesNothingWhenFolderExists" {
            Test-Path $dbLocation | Should -BeTrue

            ensureDb $dbLocation

            Test-Path $dbLocation | Should -BeTrue
            Test-Path "$dbLocation\installationDb.schemaVersion.txt" | Should -BeFalse
        }
    }
}
