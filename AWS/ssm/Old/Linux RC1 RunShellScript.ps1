param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1')
    )

. $PSScriptRoot\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
Write-Verbose "Linux RC RunShellScript: Name=$Name, InstanceId=$instanceIds"

$startTime = Get-Date
$command = SSMRunCommand -InstanceIds $instanceIds -SleepTimeInMilliSeconds 1000 `
    -DocumentName 'AWS-RunShellScript' -Parameters @{commands='ifconfig'}

Test-SSMOuput $command

$obj = @{}
$obj.'CommandId' = $command.CommandId
$obj.'Time' = (Get-Date) - $startTime

return $obj