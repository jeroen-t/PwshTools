# AutomatedLab

$labname = 'Lab1'
$password = ''

New-LabDefinition -Name $labname -DefaultVirtualizationEngine 'HyperV'
Add-LabDomainDefinition -Name domain.com -AdminUser 'administrator' -AdminPassword 'Somepass1'
Set-LabInstallationCredential -Username 'administrator' -Password 'Somepass1'

Add-LabIsoImageDefinition -Name 'SQLServer2019' -Path "$labSources\ISOs\SQLServer2019-x64-ENU-Dev.iso"

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network' = $labname
    'Add-LabMachineDefinition:DomainName' = 'domain.com'
    'Add-LabMachineDefinition:Memory' = 4GB
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2016 Datacenter Evaluation (Desktop Experience)'
}

Add-LabMachineDefinition -Name DC1 -Roles RootDC

$roleSQL = Get-LabMachineRoleDefinition -Role SQLServer2019 -Properties @{Features = 'SQL'; SQLSvcAccount = "domain\SQLService"; SQLSvcPassword = $password; SQLSysAdminAccounts = 'domain\administrator'}
$cluster = Get-LabMachineRoleDefinition -Role FailoverNode -Properties @{ ClusterName = 'Cluster'; ClusterIp = '192.168.11.111' }
Add-LabMachineDefinition -Name SQL01 -Roles $roleSQL,$cluster
Add-LabMachineDefinition -Name SQL02 -Roles $roleSQL,$cluster
Add-LabMachineDefinition -Name SQL03 -Roles $roleSQL,$cluster


Install-Lab

Show-LabDeploymentSummary -Detailed