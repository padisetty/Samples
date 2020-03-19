# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel
#     $obj - This is a dictionary, used to pass output values
#            (e.g.) report the metrics back, or pass output values that will be input to subsequent functions

Write-Verbose 'Executing Run Command'

. "$PSScriptRoot\Common Setup.ps1"


$startTime = Get-Date
$command = SSMRunCommand `
    -InstanceIds $obj.InstanceId `
    -SleepTimeInMilliSeconds 1000 `
    -Parameters @{
        commands=@(
            'ipconfig'
        )
     }

$obj.'CommandId' = $command
$obj.RunCommandTime = (Get-Date) - $startTime
SSMDumpOutput $command
