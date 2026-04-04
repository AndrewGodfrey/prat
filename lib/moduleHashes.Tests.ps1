BeforeAll {
    . "$PSScriptRoot/moduleHashes.ps1"
    $script:testRoot = (Get-Item 'TestDrive:\').FullName
}

Describe 'pratWriteModuleHash' {
    It 'creates hash dir and file if neither exists' {
        $src = "$script:testRoot/wm1/src"
        $script:_pratModuleHashDir = "$script:testRoot/wm1/hashes"
        New-Item -Type Directory $src | Out-Null
        'function foo {}' | Set-Content "$src/foo.ps1"

        pratWriteModuleHash 'Foo' $src

        "$script:testRoot/wm1/hashes/Foo.hash" | Should -Exist
    }

    It 'produces the same hash for the same content' {
        $src = "$script:testRoot/wm2/src"
        $script:_pratModuleHashDir = "$script:testRoot/wm2/hashes"
        New-Item -Type Directory $src | Out-Null
        'function foo {}' | Set-Content "$src/foo.ps1"

        pratWriteModuleHash 'Foo' $src
        $hash1 = Get-Content "$script:_pratModuleHashDir/Foo.hash"

        pratWriteModuleHash 'Foo' $src
        $hash2 = Get-Content "$script:_pratModuleHashDir/Foo.hash"

        $hash1 | Should -Be $hash2
    }

    It 'produces different hashes for different file content' {
        $src1 = "$script:testRoot/wm3/src1"
        $src2 = "$script:testRoot/wm3/src2"
        $script:_pratModuleHashDir = "$script:testRoot/wm3/hashes"
        New-Item -Type Directory $src1, $src2 | Out-Null
        'function foo {}' | Set-Content "$src1/foo.ps1"
        'function bar {}' | Set-Content "$src2/foo.ps1"

        pratWriteModuleHash 'Foo' $src1
        $hash1 = Get-Content "$script:_pratModuleHashDir/Foo.hash"

        pratWriteModuleHash 'Foo' $src2
        $hash2 = Get-Content "$script:_pratModuleHashDir/Foo.hash"

        $hash1 | Should -Not -Be $hash2
    }
}

Describe 'pratGetModuleHashSnapshot' {
    It 'returns an empty hashtable when the hash dir does not exist' {
        $script:_pratModuleHashDir = "$script:testRoot/gs1/nonexistent"

        $result = pratGetModuleHashSnapshot

        $result | Should -BeOfType [hashtable]
        $result.Count | Should -Be 0
    }

    It 'returns a hashtable mapping module names to hash values' {
        $hashDir = "$script:testRoot/gs2/hashes"
        New-Item -Type Directory $hashDir | Out-Null
        Set-Content "$hashDir/Foo.hash" 'HASH1' -NoNewline
        Set-Content "$hashDir/Bar.hash" 'HASH2' -NoNewline
        $script:_pratModuleHashDir = $hashDir

        $result = pratGetModuleHashSnapshot

        $result.Count | Should -Be 2
        $result['Foo'] | Should -Be 'HASH1'
        $result['Bar'] | Should -Be 'HASH2'
    }
}

Describe 'pratTestModulesStale' {
    It 'returns false when snapshot is null' {
        pratTestModulesStale $null | Should -BeFalse
    }

    It 'returns false when the hash dir does not exist' {
        $script:_pratModuleHashDir = "$script:testRoot/ts1/nonexistent"

        pratTestModulesStale @{} | Should -BeFalse
    }

    It 'returns false when hashes match the snapshot' {
        $hashDir = "$script:testRoot/ts2/hashes"
        New-Item -Type Directory $hashDir | Out-Null
        Set-Content "$hashDir/Foo.hash" 'HASH1' -NoNewline
        $script:_pratModuleHashDir = $hashDir

        pratTestModulesStale @{ Foo = 'HASH1' } | Should -BeFalse
    }

    It 'returns true when a hash differs from the snapshot' {
        $hashDir = "$script:testRoot/ts3/hashes"
        New-Item -Type Directory $hashDir | Out-Null
        Set-Content "$hashDir/Foo.hash" 'HASH_NEW' -NoNewline
        $script:_pratModuleHashDir = $hashDir

        pratTestModulesStale @{ Foo = 'HASH_OLD' } | Should -BeTrue
    }

    It 'returns false for modules not present in the snapshot (new module added after session start)' {
        $hashDir = "$script:testRoot/ts4/hashes"
        New-Item -Type Directory $hashDir | Out-Null
        Set-Content "$hashDir/NewModule.hash" 'HASH1' -NoNewline
        $script:_pratModuleHashDir = $hashDir

        pratTestModulesStale @{} | Should -BeFalse
    }
}
