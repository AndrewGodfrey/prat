using module .\TextFileEditor.psd1

BeforeAll { . "$PSScriptRoot/../TestHelpers.ps1" }

Describe "Find-JsonSection" {
    BeforeAll {
        $filename = "test.json"

        # Lines (0-based):
        $script:json = testTextAt 12 @"
         0: {
         1:   "profiles": {
         2:     "defaults": {},
         3:     "list": [
         4:       {
         5:         "guid": "{abc}",
         6:         "name": "Profile1"
         7:       },
         8:       {
         9:         "guid": "{def}",
        10:         "name": "Profile2"
        11:       }
        12:     ]
        13:   }
        14: }
"@
    }

    It "finds a top-level object property" {
        $result = Find-JsonSection $script:json @("profiles") $filename
        $result.idxFirst | Should -Be 1
        $result.idxLast  | Should -Be 13
    }

    It "finds a nested object property" {
        $result = Find-JsonSection $script:json @("profiles", "list") $filename
        $result.idxFirst | Should -Be 3
        $result.idxLast  | Should -Be 12
    }

    It "finds an array element by property value" {
        $result = Find-JsonSection $script:json @("profiles", "list", "[@guid='{def}']") $filename
        $result.idxFirst | Should -Be 8
        $result.idxLast  | Should -Be 11
    }

    It "handles property values containing braces" {
        # Verifies tokenizer doesn't treat { } inside strings as structural
        $result = Find-JsonSection $script:json @("profiles", "list", "[@guid='{abc}']") $filename
        $result.idxFirst | Should -Be 4
        $result.idxLast  | Should -Be 7
    }

    It "finds a simple string value (key + value on same line)" {
        $result = Find-JsonSection $script:json @("profiles", "list", "[@guid='{def}']", "name") $filename
        $result.idxFirst | Should -Be 10
        $result.idxLast  | Should -Be 10
    }

    It "finds keys after a boolean value (tokenizer stop-chars)" {
        # Regression: single-quoted stop-chars string in the tokenizer didn't use
        # actual control chars for `r/`n/`t, so values ran to end-of-input and
        # swallowed subsequent tokens.
        $jsonWithBools = testText @"
            {
              "a": true,
              "b": false
            }
"@
        $ra = Find-JsonSection $jsonWithBools @("a") $filename
        $rb = Find-JsonSection $jsonWithBools @("b") $filename

        $ra.idxFirst | Should -Be 1
        $ra.idxLast  | Should -Be 1
        $rb.idxFirst | Should -Be 2
        $rb.idxLast  | Should -Be 2
    }

    It "returns null when key not found" {
        $result = Find-JsonSection $script:json @("missing") $filename
        $result | Should -BeNull
    }

    It "returns null when array element not found" {
        $result = Find-JsonSection $script:json @("profiles", "list", "[@guid='{zzz}']") $filename
        $result | Should -BeNull
    }
}

Describe "Update-JsonSection" {
    BeforeAll {
        $filename = "test.json"
        $script:json = testText @"
            {
              "profiles": {
                "defaults": {},
                "list": [
                  {
                    "guid": "{abc}",
                    "name": "Profile1"
                  },
                  {
                    "guid": "{def}",
                    "name": "Profile2"
                  }
                ]
              }
            }
"@
    }

    It "replaces an existing array element" {
        $newEntry = testTextAt 12 @"
                  {
                    "guid": "{def}",
                    "name": "Updated"
                  }
"@
        $result = Update-JsonSection $script:json @("profiles", "list", "[@guid='{def}']") $newEntry $filename
        $result | Should -Be (testText @"
            {
              "profiles": {
                "defaults": {},
                "list": [
                  {
                    "guid": "{abc}",
                    "name": "Profile1"
                  },
                  {
                    "guid": "{def}",
                    "name": "Updated"
                  }
                ]
              }
            }
"@)
    }

    It "adds a new array element when not found" {
        $newEntry = testTextAt 12 @"
                  {
                    "guid": "{new}",
                    "name": "NewProfile"
                  }
"@
        $result = Update-JsonSection $script:json @("profiles", "list", "[@guid='{new}']") $newEntry $filename
        $result | Should -Be (testText @"
            {
              "profiles": {
                "defaults": {},
                "list": [
                  {
                    "guid": "{abc}",
                    "name": "Profile1"
                  },
                  {
                    "guid": "{def}",
                    "name": "Profile2"
                  },
                  {
                    "guid": "{new}",
                    "name": "NewProfile"
                  }
                ]
              }
            }
"@)
    }

    It "adds the first element to a single-line empty array" {
        $json = testText @"
            {
                "list": []
            }
"@
        $newEntry = '    { "guid": "{x}" }'
        $result = Update-JsonSection $json @("list", "[@guid='{x}']") $newEntry "test.json"
        $parsed = ConvertFrom-Json $result -AsHashtable
        $parsed.list.Count    | Should -Be 1
        $parsed.list[0]['guid'] | Should -Be '{x}'
    }

    It "preserves trailing comma when replacing a non-last array element" {
        $newEntry = testTextAt 12 @"
                  {
                    "guid": "{abc}",
                    "name": "Updated"
                  }
"@
        $result = Update-JsonSection $script:json @("profiles", "list", "[@guid='{abc}']") $newEntry $filename
        # {abc} is not the last element, so its closing line must keep its comma
        $result | Should -Be (testText @"
            {
              "profiles": {
                "defaults": {},
                "list": [
                  {
                    "guid": "{abc}",
                    "name": "Updated"
                  },
                  {
                    "guid": "{def}",
                    "name": "Profile2"
                  }
                ]
              }
            }
"@)
    }

    It "throws if parent section not found" {
        { Update-JsonSection $script:json @("missing", "[@guid='{x}']") "x" $filename } |
            Should -Throw -ExpectedMessage "Can't find 'missing' section in 'test.json'"
    }
}

Describe "Move-JsonArrayElementToFirst" {
    BeforeAll {
        $filename = "test.json"
        $script:json = testText @"
            {
              "profiles": {
                "defaults": {},
                "list": [
                  {
                    "guid": "{abc}",
                    "name": "Profile1"
                  },
                  {
                    "guid": "{def}",
                    "name": "Profile2"
                  }
                ]
              }
            }
"@
    }

    It "moves the last element to first position" {
        $result = Move-JsonArrayElementToFirst $script:json @("profiles", "list", "[@guid='{def}']") $filename
        $result | Should -Be (testText @"
            {
              "profiles": {
                "defaults": {},
                "list": [
                  {
                    "guid": "{def}",
                    "name": "Profile2"
                  },
                  {
                    "guid": "{abc}",
                    "name": "Profile1"
                  }
                ]
              }
            }
"@)
    }

    It "moves a middle element to first position" {
        $json3 = testText @"
            {
              "list": [
                { "id": "a" },
                { "id": "b" },
                { "id": "c" }
              ]
            }
"@
        $result = Move-JsonArrayElementToFirst $json3 @("list", "[@id='b']") $filename
        $parsed = ConvertFrom-Json $result -AsHashtable
        $parsed.list[0]['id'] | Should -Be 'b'
        $parsed.list[1]['id'] | Should -Be 'a'
        $parsed.list[2]['id'] | Should -Be 'c'
    }

    It "is a no-op when the element is already first" {
        $result = Move-JsonArrayElementToFirst $script:json @("profiles", "list", "[@guid='{abc}']") $filename
        $result | Should -Be $script:json
    }

    It "is a no-op when the element is not found" {
        $result = Move-JsonArrayElementToFirst $script:json @("profiles", "list", "[@guid='{zzz}']") $filename
        $result | Should -Be $script:json
    }

    It "moves the last element to first when the opening bracket is on its own line" {
        $jsonSeparateBracket = testText @"
            {
              "profiles": {
                "list":
                [
                  {
                    "guid": "{abc}",
                    "name": "Profile1"
                  },
                  {
                    "guid": "{def}",
                    "name": "Profile2"
                  }
                ]
              }
            }
"@
        $result = Move-JsonArrayElementToFirst $jsonSeparateBracket @("profiles", "list", "[@guid='{def}']") $filename
        $parsed = ConvertFrom-Json $result -AsHashtable
        $parsed.profiles.list[0]['guid'] | Should -Be '{def}'
        $parsed.profiles.list[1]['guid'] | Should -Be '{abc}'
    }
}
