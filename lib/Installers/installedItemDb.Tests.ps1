BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe "getCurrentSchemaVersion" {
    It "Returns a version number" {
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
    It "Verifies silently" {
        checkSchemaVersion "dbLocation" | Should -Be $null
    }
    It "Throws on mismatch" {
        Mock getCurrentSchemaVersion { "2.2" }
        {checkSchemaVersion "dbLocation"} | Should -Throw "Schema version mismatch. Expected: '2.2'  Actual: '2.1'"
    }
}

Describe "getStateFilePath" {
    It "concatenates" {
        getStateFilePath "db" "id" | Should -Be "db\id.txt"
    }
    It "limits character set on id" {
        {getStateFilePath "db" "#a"} | Should -Throw "Unsupported format for itemId '#a'. Use only alphanumeric, underscore and slash; first char an alphanumeric."
    }
}

Describe "getForkpointCacheStateFilePath" {
    It "concatenates" {
        getForkpointCacheStateFilePath "db" "id_" | Should -Be "db\_forkpointCache\id_.ps1"
    }
    It "limits character set on id" {
        {getForkpointCacheStateFilePath "db" "_a"} | Should -Throw "Unsupported format for itemId '_a'. Use only alphanumeric, underscore and slash; first char an alphanumeric."
    }
}

Describe "Test-InstalledItemVersion" {
    BeforeEach {
        Mock Get-InstalledItemVersion {"9.7"}
    }
    It "Returns true when the versions match" {
        Test-InstalledItemVersion $dbLocation "item" "9.7" | Should -Be $true
    }
    It "Returns false when expected version is newer" {
        Test-InstalledItemVersion $dbLocation "item" "10.1" | Should -Be $false
    }
    It "Returns false when there's no installed version" {
        Mock Get-InstalledItemVersion { $null }
        Test-InstalledItemVersion $dbLocation "item" "10.1" | Should -Be $false
    }
    It "Throws when expected version is older" {
        {Test-InstalledItemVersion $dbLocation "item" "8.0"} | Should -Throw "Unexpected: item: Current version is newer: 9.7 > 8.0"
    }
}

Describe "Using TestDrive" {
    BeforeEach {
        $dbLocation = "TestDrive:\installedItemDb.Tests.ps1"
        mkdir $dbLocation | Out-Null
    }
    AfterEach {
        Remove-Item -Recurse $dbLocation | Out-Null
    }
    Context "Get-InstalledItemVersion" {
        It "Returns the state file contents" {
            Mock checkSchemaVersion {}
            New-Item -Path "$dbLocation\item.txt" -ItemType File -Value "9.7" | Out-Null
            
            Get-InstalledItemVersion $dbLocation "item" | Should -Be "9.7"
        }
        It "Returns null (i.e. no installed version) when dbLocation doesn't exist" {
            Get-InstalledItemVersion "$dbLocation\notExist" "id" | Should -BeNull
        }
        It "Returns null when item has no state file" {
            Mock checkSchemaVersion {}
            Test-Path $dbLocation | Should -BeTrue

            Get-InstalledItemVersion $dbLocation "idNotExist" | Should -BeNull
        }
    }
    Context "Set-InstalledItemVersion" {
        It "Returns the state file contents" {
            Mock checkSchemaVersion {}
            
            Set-InstalledItemVersion $dbLocation "parent/item" "9.2.1"

            Test-Path "$dbLocation\parent\item.txt" | Should -BeTrue
            Get-Content "$dbLocation\parent\item.txt" | Should -Be "9.2.1"
        }
    }
    Context "Remove-InstalledItem" {
        It "Removes the item" {
            Mock checkSchemaVersion {}
            Set-InstalledItemVersion $dbLocation "parent/item" "9.2.1"
            Test-Path "$dbLocation\parent\item.txt" | Should -BeTrue

            Remove-InstalledItem $dbLocation "parent/item"

            Test-Path "$dbLocation\parent\item.txt" | Should -BeFalse
            Test-Path "$dbLocation\parent" | Should -BeTrue # It doesn't fully clean up
        }
    }
    Context "ensureDb" {
        It "Creates the folder and schema version" {
            Mock getCurrentSchemaVersion {"5.5"}
            $db = "$dbLocation\notExist2"
            Test-Path $db | Should -BeFalse

            ensureDb $db

            Test-Path $db | Should -BeTrue
            Get-Content "$db\installationDb.schemaVersion.txt" | Should -Be "5.5"
        }
        It "Does nothing for an existing folder" {
            Test-Path $dbLocation | Should -BeTrue

            ensureDb $dbLocation

            Test-Path $dbLocation | Should -BeTrue
            Test-Path "$dbLocation\installationDb.schemaVersion.txt" | Should -BeFalse
        }
    }
}
