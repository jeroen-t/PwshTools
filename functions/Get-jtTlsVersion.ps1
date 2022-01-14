function Get-jtTlsVersion {
    Param (
        [parameter(Mandatory)]
        [string[]]$protocol
    )
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

    Get-ChildItem -Path $path | Where-Object PSchildName -in $protocol | ForEach-Object {
        $protocolpath = $_.pspath
        'Client','Server' | ForEach-Object {
            $fullpath = Join-Path $protocolpath $_
            if (Test-Path $fullpath) {
                $val = Get-ItemProperty $fullpath
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    Protocol = $val.PSParentPath -replace '.*\\'
                    Key = $val.PSPath -replace '.*\\'
                    DisabledByDefault = $val.DisabledByDefault
                    Enabled = $val.Enabled
                }
            }
        }
    }
}

$computer = 'greenskins','skaven'
$protocol = @('tls 1.2','tls 1.3')
Invoke-Command -ScriptBlock ${function:Get-jtTlsVersion} -ArgumentList (,$protocol) -ComputerName $computer
