Describe "Analyze-FileExtensions" {
    BeforeEach {
        pushd $PSScriptRoot\Analyze-FileExtensions
    }
    AfterEach {
        popd
    }
    It "summarizes by file extension" {
        $result = Analyze-FileExtensions 

        $result.Count | Should -Be 2
        $result[0].Count | Should -Be 1
        $result[0].Name | Should -Be ".log"
        $result[1].Count | Should -Be 2
        $result[1].Name | Should -Be ".txt"
    }
    It "supports recursion" {
        $result = Analyze-FileExtensions -Recurse

        $result.Count | Should -Be 2
        $result[1].Count | Should -Be 3
    }
}
