# Visual Studio will often set us up the BOM. And other tools remove it again.
# To help with this:
#
# get: Retrieves the encoding for each matching file
# set: Changes the encoding for each matching file. Only utf8 and utf8 + BOM are supported.
#      (And I don't recommend utf8 + BOM - it's just for testing).

param ([ValidateSet("get", "apply")] $command, $pathspec="*.csproj", $toApply)

switch ($command) {
  "get" { 
    $result = @{}
    Get-ChildItem -Recurse -File $pathSpec | % { 
      $fmt = Get-TextFileEncoding $_.FullName -FromScript
      echo @{ File = $_; Format = $fmt }
    }
  }

  "set" {
    Get-ChildItem -Recurse -File $pathSpec | % {
      $file = $_.FullName
      $expectedFmt = $toApply[$file]
      if ($null -eq $expectedFmt) { throw "Missing information for file: $file" }
      $actualFmt = Get-TextFileEncoding $file -FromScript
      if ($expectedFmt -ne $actualFmt) { 
        if (($expectedFmt -eq 'utf8') -and ($actualFmt -eq 'utf8 + BOM')) {
          Remove-Utf8Bom $file
        } elseif (($expectedFmt -eq 'utf8 + BOM') -and ($actualFmt -eq 'utf8')) {
          Add-Utf8Bom $file
        } else {
          Write-Warning "Not implemented: $actualFmt -> $($expectedFmt): $file"
        }
      }
    }
  }
}

