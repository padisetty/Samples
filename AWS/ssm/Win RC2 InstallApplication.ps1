param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmwindows'), 
    $InstanceIds = $InstanceIds,
    $MSIPath1 = 'https://downloads.sourceforge.net/project/sevenzip/7-Zip/17.01/7z1701-x64.msi',
    $MSIPath2 = 'https://downloads.sourceforge.net/project/sevenzip/7-Zip/18.01/7z1801-x64.msi',
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )

. $PSScriptRoot\ssmcommon.ps1 $Region
if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
Write-Verbose "Windows RC3 InstallApplication: Name=$Name, InstanceId=$instanceIds"

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

#Run Command
$startTime = Get-Date
$command = SSMRunCommand `
    -InstanceIds $InstanceIds `
    -DocumentName 'AWS-InstallApplication' `
    -Parameters @{
        source=$MSIPath1
        action='Install'
     } 

$obj = @{}
$obj.'CommandId' = $command
$obj.'RunCommandTime' = (Get-Date) - $startTime


$command = SSMRunCommand `
    -InstanceIds $InstanceIds `
    -Parameters @{
        commands='gwmi win32_product | ? Name -like "7-zip*" | select Name'
     } 
Test-SSMOuput $command -ExpectedMinLength 0 -ExpectdOutput '7-Zip 15.12 (x64 edition)'

if ($SetupAction -eq 'SetupOnly') {
    return
}

<#
#Upgrade
$command = SSMRunCommand `
    -InstanceIds $InstanceIds `
    -DocumentName 'AWS-InstallApplication' `
    -Parameters @{
        source=$MSIPath2
     } 

$cmd = {
    $command = SSMRunCommand `
        -InstanceIds $InstanceIds `
        -Parameters @{
            commands='gwmi win32_product | ? Name -like "7-zip*" | select Name'
         } 
    Test-SSMOuput $command -ExpectedMinLength 0 -ExpectedOutput '7-Zip 16.04 (x64 edition)'
}
Invoke-PSUtilRetryOnError -ScriptBlock $cmd -RetryCount 3 -SleepTimeInMilliSeconds 10
#>


#Uninstall

$command = SSMRunCommand `
    -InstanceIds $InstanceIds `
    -DocumentName 'AWS-InstallApplication' `
    -Parameters @{
        source=$MSIPath1
        action='Uninstall'
     } 

$cmd = {
    $command = SSMRunCommand `
        -InstanceIds $InstanceIds `
        -Parameters @{
            commands='gwmi win32_product | ? Name -like "7-zip*" | select Name'
    } 
    Test-SSMOuput $command -ExpectedMinLength 0 -ExpectedMaxLength 0
}

Invoke-PSUtilRetryOnError -ScriptBlock $cmd -RetryCount 3 -SleepTimeInMilliSeconds 10

return $obj