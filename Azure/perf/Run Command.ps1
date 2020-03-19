# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel
#     $obj - This is a dictionary, used to pass output values
#            (e.g.) report the metrics back, or pass output values that will be input to subsequent functions
param ($Name = '', $SSMRegion='us-east-1')
Write-Verbose 'Executing Run Command'

. "$PSScriptRoot\Common Setup.ps1"


$filter = @{Key='ActivationIds'; ValueSet=$Obj.'ActivationId'}
$mi = (Get-SSMInstanceInformation -InstanceInformationFilterList $filter -Region $SSMRegion).InstanceId


$startTime = Get-Date
$command = SSMRunCommand `
    -InstanceIds $mi `
    -SleepTimeInMilliSeconds 1000 `
    -Parameters @{
        commands=@(
            'ipconfig'
        )
     }

$obj.'mi-CommandId' = $command
$obj.'Mi-RunCommandTime' = (Get-Date) - $startTime
SSMDumpOutput $command