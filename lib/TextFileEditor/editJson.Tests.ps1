using module .\TextFileEditor.psd1

Describe "Find-JsonSection" {
    BeforeAll {
        $filename = "test.json"

        # Lines (0-based):
        #  0: {
        #  1:   "profiles": {
        #  2:     "defaults": {},
        #  3:     "list": [
        #  4:       {
        #  5:         "guid": "{abc}",
        #  6:         "name": "Profile1"
        #  7:       },
        #  8:       {
        #  9:         "guid": "{def}",
        # 10:         "name": "Profile2"
        # 11:       }
        # 12:     ]
        # 13:   }
        # 14: }
        $script:json = "{`n" +
            "  `"profiles`": {`n" +
            "    `"defaults`": {},`n" +
            "    `"list`": [`n" +
            "      {`n" +
            "        `"guid`": `"{abc}`",`n" +
            "        `"name`": `"Profile1`"`n" +
            "      },`n" +
            "      {`n" +
            "        `"guid`": `"{def}`",`n" +
            "        `"name`": `"Profile2`"`n" +
            "      }`n" +
            "    ]`n" +
            "  }`n" +
            "}"
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
        $jsonWithBools = "{`n  `"a`": true,`n  `"b`": false`n}"
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
        $script:json = "{`n" +
            "  `"profiles`": {`n" +
            "    `"defaults`": {},`n" +
            "    `"list`": [`n" +
            "      {`n" +
            "        `"guid`": `"{abc}`",`n" +
            "        `"name`": `"Profile1`"`n" +
            "      },`n" +
            "      {`n" +
            "        `"guid`": `"{def}`",`n" +
            "        `"name`": `"Profile2`"`n" +
            "      }`n" +
            "    ]`n" +
            "  }`n" +
            "}"
    }

    It "replaces an existing array element" {
        $newEntry = "      {`n        `"guid`": `"{def}`",`n        `"name`": `"Updated`"`n      }"
        $result = Update-JsonSection $script:json @("profiles", "list", "[@guid='{def}']") $newEntry $filename
        $result | Should -Be ("{`n" +
            "  `"profiles`": {`n" +
            "    `"defaults`": {},`n" +
            "    `"list`": [`n" +
            "      {`n" +
            "        `"guid`": `"{abc}`",`n" +
            "        `"name`": `"Profile1`"`n" +
            "      },`n" +
            "      {`n" +
            "        `"guid`": `"{def}`",`n" +
            "        `"name`": `"Updated`"`n" +
            "      }`n" +
            "    ]`n" +
            "  }`n" +
            "}")
    }

    It "adds a new array element when not found" {
        $newEntry = "      {`n        `"guid`": `"{new}`",`n        `"name`": `"NewProfile`"`n      }"
        $result = Update-JsonSection $script:json @("profiles", "list", "[@guid='{new}']") $newEntry $filename
        $result | Should -Be ("{`n" +
            "  `"profiles`": {`n" +
            "    `"defaults`": {},`n" +
            "    `"list`": [`n" +
            "      {`n" +
            "        `"guid`": `"{abc}`",`n" +
            "        `"name`": `"Profile1`"`n" +
            "      },`n" +
            "      {`n" +
            "        `"guid`": `"{def}`",`n" +
            "        `"name`": `"Profile2`"`n" +
            "      },`n" +
            "      {`n" +
            "        `"guid`": `"{new}`",`n" +
            "        `"name`": `"NewProfile`"`n" +
            "      }`n" +
            "    ]`n" +
            "  }`n" +
            "}")
    }

    It "adds the first element to a single-line empty array" {
        $json = "{`n    `"list`": []`n}"
        $newEntry = '    { "guid": "{x}" }'
        $result = Update-JsonSection $json @("list", "[@guid='{x}']") $newEntry "test.json"
        $parsed = ConvertFrom-Json $result -AsHashtable
        $parsed.list.Count    | Should -Be 1
        $parsed.list[0]['guid'] | Should -Be '{x}'
    }

    It "preserves trailing comma when replacing a non-last array element" {
        $newEntry = "      {`n        `"guid`": `"{abc}`",`n        `"name`": `"Updated`"`n      }"
        $result = Update-JsonSection $script:json @("profiles", "list", "[@guid='{abc}']") $newEntry $filename
        # {abc} is not the last element, so its closing line must keep its comma
        $result | Should -Be ("{`n" +
            "  `"profiles`": {`n" +
            "    `"defaults`": {},`n" +
            "    `"list`": [`n" +
            "      {`n" +
            "        `"guid`": `"{abc}`",`n" +
            "        `"name`": `"Updated`"`n" +
            "      },`n" +
            "      {`n" +
            "        `"guid`": `"{def}`",`n" +
            "        `"name`": `"Profile2`"`n" +
            "      }`n" +
            "    ]`n" +
            "  }`n" +
            "}")
    }

    It "throws if parent section not found" {
        { Update-JsonSection $script:json @("missing", "[@guid='{x}']") "x" $filename } |
            Should -Throw -ExpectedMessage "Can't find 'missing' section in 'test.json'"
    }
}
