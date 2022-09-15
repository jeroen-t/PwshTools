BeforeAll {
    function Get-Version () {
        $PSVersionTable.PSVersion
    }
}

Describe 'PowerShell' {
    It 'Version should be equal to or greater than 7.0' {
        Get-Version | Should -BeGreaterOrEqual 7.0
    }
}
