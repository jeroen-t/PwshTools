Function Get-jtSqlAgRole {
    <#
        .SYNOPSIS
            Function that will get the Primary and Secondary server role of the specified Availability Group(s).
        .DESCRIPTION
            Function that will get the Primary and Secondary server role of the specified Availability Group(s).
        .PARAMETER AvailabilityGroupName
            Specifies the name of the Availability Group.
        .EXAMPLE
            - Example 1: Get the roles for an Availability Group -
    
            PS C:\> Get-jtSqlAgRole -AvailabilityGroupName "Available"
    
            AvailabilityGroupName PrimaryServer SecondaryServer
            --------------------- ------------- ---------------
            Available             SomeServer01  SomeServer02
        .EXAMPLE
            - Example 2: Get the roles for multiple piped Availability Groups -
    
            PS C:\> "Available","DenverCoder9","AwesomeMix" | Get-jtSqlAgRole
    
            AvailabilityGroupName PrimaryServer SecondaryServer
            --------------------- ------------- ---------------
            Available             SomeServer01  SomeServer02
            DenverCoder9          Sequel01      Sequel02
            AwesomeMix            Volume01      Volume02
        .EXAMPLE
            - Example 3: Get the roles for multiple Availability Groups -
    
            PS C:\> Get-jtSqlAgRole -AG "Available","DenverCoder9","AwesomeMix"
    
            AvailabilityGroupName PrimaryServer SecondaryServer
            --------------------- ------------- ---------------
            Available             SomeServer01  SomeServer02
            DenverCoder9          Sequel01      Sequel02
            AwesomeMix            Volume01      Volume02
    
    #>
        [CmdletBinding()]
        [Alias("Get-AGRole")]
        param (
            [Parameter(Mandatory=$true,
            ValueFromPipeline=$true)]
            [Alias("AG","AvailabilityGroup")]
            [string[]]$AvailabilityGroupName
        )
    
        Begin {
            Write-Verbose "[$((Get-Date).TimeOfDay)] 3..2..1.. GO! $($myinvocation.mycommand)"
        } #begin
    
        Process {
            foreach ($AG in $AvailabilityGroupName) {
                Write-Verbose "Searching for the replicas for Avaivability Group: $AG."
                try {
                    $PrimaryServer = (Get-SqlInstance -ServerInstance $AG).NetName
                    $AgPrimaryPath = "SQLSERVER:\SQL\$PrimaryServer\Default\AvailabilityGroups\$AG"
                    $SecondaryServer = (Get-ChildItem -Path $AgPrimaryPath\AvailabilityReplicas | Where-Object {$_.Role -eq 'Secondary'}).Name
                    $props = [ordered]@{
                        AvailabilityGroupName = $AG
                        PrimaryServer = $PrimaryServer
                        SecondaryServer = $SecondaryServer
                    }
                    $obj = New-Object -TypeName PSObject -Property $props
                    Write-Output $obj
                } catch {
                    Write-Error $_.Exception.Message
                }
            } #foreach
        } #process
    
        End {
            Write-Verbose "[$((Get-Date).TimeOfDay)] Ending $($myinvocation.mycommand)"
        } #end
    }