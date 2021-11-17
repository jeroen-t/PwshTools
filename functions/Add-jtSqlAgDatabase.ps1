Function Add-jtSqlAgDatabase {
<#
.SYNOPSIS
    Adds a primary database and joins a secondary database to an Availability Group.
    
.DESCRIPTION
    The Add-jtSqlAgDatabase cmdlet adds a primary database and joins a secondary database o an Availability Group (AG) by backing up to and restoring from a shared path.
    A database can bleong to only one AG.

    To add database(s) to an AG, make sure the specified database is hosted on the primary replica.

.PARAMETER Name
    Specifies an array of user databases. This cmdlet adds the databases that this parameter specifies to the Availability Group (AG). The database(s) that you specify must reside on the primary replica of the AG.

.PARAMETER AvailabilityGroupName
    Specifies the Availability Group name to which this cmdlet adds the specified database(s).

.PARAMETER Path
    Specifies the SMB Share to which the database(s) are backed up. The backup location must be accessible to the SQL Server Instances and have sufficient space to store the backup files.

    If no Path is specified the following path will be tried: "\\<PrimaryReplica>\Backup\".

.EXAMPLE
    - Example 1: Add database "StackOverflow2010" hosted on server "Volume01" to Availability Group "AwesomeMix", where "Volume01" is the primary replica. -

    PS C:\> Add-jtSqlAgDatabase -Name StackOverflow2010 -AvailabilityGroupName AwesomeMix -Path '\\Volume01\Backup\'

.EXAMPLE
    - Example 2: Add databases "StackOverflow2010" and "ReplicateMe" hosted on server "Volume01" to Availability Group "AwesomeMix", where "Volume01" is the primary replica. -

    PS C:\> "StackOverflow2010","ReplicateMe" | Add-jtSqlAgDatabase -AvailabilityGroupName AwesomeMix -Path '\\Volume01\Backup\'

.EXAMPLE
    - Example 3: Add databases "StackOverflow2010" and "ReplicateMe" hosted on server "Volume01" to Availability Group "AwesomeMix", where "Volume01" is the primary replica. -

    PS C:\> $databases = @('StackOverflow2010','ReplicateMe')
    PS C:\> Add-jtSqlAgDatabase -Name $databases -AvailabilityGroupName AwesomeMix -Path '\\Volume01\Backup\'

.NOTES
    Author: Jeroen Trimbach
    Website: Https://jeroentrimbach.com
#>
    [CmdletBinding()]
    [Alias("Add-AGDatabase")]
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
        try {
            $AGReplica = Get-jtSqlAgRole -AvailabilityGroupName $AvailabilityGroupName -ErrorAction Stop
            if([string]::IsNullOrWhiteSpace($Path)){
                $Path = "\\$($AGReplica.PrimaryServer)\Backup\"
                Write-Verbose "No backup path specified. Trying.. `"$Path`"."
            }
            if (!($Path.Substring(0,2) -eq '\\')) {
                Write-Error "$Path is not an SMB Share. Cancelling script." -ErrorAction Stop
            }
            if (Test-Path -Path $Path){
                Write-Verbose "Backup path exists!"
                if($Path -notmatch '\\$'){
                    $path += '\'
                }
                Write-Verbose "Location: $Path"
            } else {
                Write-Error "The path `"$Path`" doesn't exist. Please specify a valid backup location." -ErrorAction Stop
            }
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Stop
        }
    } #begin

    Process {
        $output = foreach ($database in $Name) {
            Write-Verbose "Trying to add the database $database to Availabilty Group: $AvailabilityGroupName."
            try {
                Write-Verbose "Checking whether the database $database is available on the primary replica.."

                $DB = Get-SqlDatabase -ServerInstance $AvailabilityGroupName -Name $database -ErrorAction Stop
                if($DB.RecoveryModel -ne 'Full') {
                    Write-Verbose 'Changing the recovery model of the database to "Full".' 
                    $DB.RecoveryModel = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Full
                    $DB.Alter()
                }
                
                Write-Verbose "Initiating full backup.."
                $BackupFilesFull = for($i=1; $i -le 8; $i++) {
                    $Path + $database + $i + '.BAK'
                }
                $propsFullBak = @{
                    Database = $database
                    BackupFile = $BackupFilesFull
                    ServerInstance = $AGReplica.PrimaryServer
                    ErrorAction = 'Stop'
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
                    ErrorAction = 'Stop'
                }
                Backup-SqlDatabase @propsLogTrn

                Write-Verbose "Log backup done! Restoring full backup on replica: $($AGReplica.SecondaryServer)."
                $propsFullBakRestore = @{
                    Database = $database
                    BackupFile = $BackupFilesFull
                    ServerInstance = $AGReplica.SecondaryServer
                    NoRecovery = $true
                    ErrorAction = 'Stop'
                }
                Restore-SqlDatabase @propsFullBakRestore

                Write-Verbose "Full backup restored. Restoring log backup.."
                $propsLogTrnRestore = @{
                    Database = $database
                    BackupFile = $BackupFilesLog
                    ServerInstance = $AGReplica.SecondaryServer
                    RestoreAction = 'Log'
                    NoRecovery = $true
                    ErrorAction = 'Stop'
                }
                Restore-SqlDatabase @propsLogTrnRestore

                Write-Verbose "Log backup restored. Adding database to the AG on the primary replica."
                Add-SqlAvailabilityDatabase -Path $AGReplica.PrimaryPath -Database $database -ErrorAction Stop

                Write-Verbose "Database is added to the AG on the primary replica. Adding on secondary replica.."
                Add-SqlAvailabilityDatabase -Path $AGReplica.SecondaryPath -Database $database -ErrorAction Stop

                Write-Verbose "$database is added to the Availability Group: $AvailabilityGroupName."

                $BackupFilesFull + $BackupFilesLog
            } catch {
                Write-Error $_.Exception.Message -ErrorAction Stop
            }
        } #foreach
    } #process

    End {
        Write-Verbose "Cleaning up backup files.."
        try {
            Remove-Item $output | Out-Null
        } catch {
            Write-Error $_.Exception.Message
        }
        Write-Verbose "[$((Get-Date).TimeOfDay)] Ending $($myinvocation.mycommand)"
    } #end
}