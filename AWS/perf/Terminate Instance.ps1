# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel
#     $obj - This is a dictionary, used to pass output values
#            (e.g.) report the metrics back, or pass output values that will be input to subsequent functions

param ($Name = '')

Write-Verbose 'Executing Terminate Instance'

. "$PSScriptRoot\Common Setup.ps1"

$Name = "perf$Name"

Remove-WinEC2Instance $Name -NoWait
