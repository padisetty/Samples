param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $DocumentName = 'AWS-RunShellScript',
    [Hashtable] $Parameters = @{commands=@('ifconfig')},
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
)

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

. ..\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
Write-Verbose "Send Command: Name=$Name, InstanceId=$instanceIds, DocumentName=$DocumentName, Parameters=$Parameters"

$startTime = Get-Date
$command = SSMRunCommand -InstanceIds $instanceIds -SleepTimeInMilliSeconds 1000 `
    -DocumentName $DocumentName -Parameters $Parameters

Test-SSMOuput $command

$obj = @{}
$obj.'CommandId' = $command.CommandId
$obj.'Time' = (Get-Date) - $startTime

return $obj