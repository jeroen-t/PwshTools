Function Add-jtSqlAgDatabase {
<#
    .SYNOPSIS
        [Placeholder Text]
    .DESCRIPTION
        [Placeholder Text]
    .PARAMETER [Placeholder]]
        [Placeholder Text]
    .EXAMPLE
        - Example 1: [Placeholder Text] -

        PS C:\>

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true)]
        [Alias("DatabaseName")]
        [string[]]$Name,

        [Parameter(Mandatory=$true)]
        [Alias("AG","AvailabilityGroup")]
        [string]$AvailabilityGroupName,

        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    Begin {
        Write-Verbose "[$((Get-Date).TimeOfDay)] 3..2..1.. GO! $($myinvocation.mycommand)."
        $AGReplica = Get-jtSqlAgRole -AvailabilityGroupName $AvailabilityGroupName
        if([string]::IsNullOrWhiteSpace($Path)){
            $Path = "\\$($AGReplica.PrimaryServer)\Backup\"
            Write-Verbose "No backup path specified. Trying.. `"$Path`"."
        }
        if (!($Path.Substring(0,2) -eq '\\')) {
            Write-Error "$Path is not an SMB Share. Cancelling script."
            Exit 1
        }
        if (Test-Path -Path $Path){
            Write-Verbose "Backup path exists!"
            if($Path -notmatch '\\$'){
                $path += '\'
            }
            Write-Verbose "Location: $Path"
        } else {
            Write-Error "The path `"$Path`" doesn't exist. Please specify a valid backup location."
            Exit 1
        } 
    } #begin

    Process {
        foreach ($database in $Name) {
            Write-Verbose "Trying to add the database $database to Availabilty Group: $AvailabilityGroupName."
            try {
                Write-Verbose "Checking whether the database $database is available on the primary replica.."
                Get-SqlDatabase -ServerInstance $AvailabilityGroupName -Name $database -ErrorAction Stop
                
                Write-Verbose "Initiating full backup.."
                $BackupFilesFull = for($i=1; $i -le 8; $i++) {
                    $Path + $database + $i + '.BAK'
                }
                $propsFullBak = @{
                    Database = $database
                    BackupFile = $BackupFilesFull
                    ServerInstance = $AGReplica.PrimaryServer
                }
                Backup-SqlDatabase @propsFullBak

                Write-Verbose "Full backup done! Initiating log backup.."
                $BackupFilesLog = for($i=1; $i -le 8; $i++) {
                    $Path + $database + $i + '.TRN'
                }
                $propsLogTrn = @{
                    Database = $database
                    BackupFile = $BackupFilesLog
                    ServerInstance =  $AGReplica.PrimaryServer
                    BackupAction = 'Log'
                }
                Backup-SqlDatabase @propsLogTrn

                Write-Verbose "Log backup done! Restoring full backup on replica: $($AGReplica.SecondaryServer)."
                $propsFullBakRestore = @{
                    Database = $database
                    BackupFile = $BackupFilesFull
                    ServerInstance = $AGReplica.SecondaryServer
                    NoRecovery = $true
                }
                Restore-SqlDatabase @propsFullBakRestore

                Write-Verbose "Full backup restored. Restoring log backup.."
                $propsLogTrnRestore = @{
                    Database = $database
                    BackupFile = $BackupFilesLog
                    ServerInstance = $AGReplica.SecondaryServer
                    RestoreAction = 'Log'
                    NoRecovery = $true
                }
                Restore-SqlDatabase @propsLogTrnRestore

                Write-Verbose "Log backup restored. Adding database to the AG on the primary replica."
                Add-SqlAvailabilityDatabase -Path $AGReplica.PrimaryPath -Database $database

                Write-Verbose "Database is added to the AG on the primary replica. Adding on secondary replica.."
                Add-SqlAvailabilityDatabase -Path $AGReplica.SecondaryPath -Database $database

                Write-Verbose "$database is added to the Availability Group: $AvailabilityGroupName."

            } catch {
                Write-Error $_.Exception.Message
                Exit 1
            }
        } #foreach
    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeOfDay)] Ending $($myinvocation.mycommand)"
    } #end
}

Add-jtSqlAgDatabase -Name jeroen -AvailabilityGroupName "Available" -Path \\comp\Temp -Verbose

<#
Add-jtSqlAgDatabase -Name jeroen -AvailabilityGroupName jeroen -Path lol -Verbose

"jeroen1","jeroen2","bar" | Add-jtSqlAgDatabase -ag 'lol' -verbose

Add-jtSqlAgDatabase -Name '1','twee','tester' -AvailabilityGroupName friend -Verbose