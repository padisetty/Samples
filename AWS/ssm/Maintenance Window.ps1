param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $ParallelIndex,
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )

. $PSScriptRoot\ssmcommon.ps1 $Region

$parallelName = "$Name$ParallelIndex"
$ErrorActionPreference='continue'
$MWName = "Execute_Every_Five_Minutes-$($parallelName)"

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name, ParallelIndex=$ParallelIndex"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
Write-Verbose "Maintenance Window: Name=$Name, InstanceId=$instanceIds, SetupAction=$SetupAction, ParallelIndex=$ParallelIndex"

$window = Get-SSMMaintenanceWindowList -Filter @{Key='Name';Values=$MWName}
if ($window) {
    Write-Verbose "Removing Maintenance Window $($window.Name), WindowId=$($window.WindowId)"
    Remove-SSMMaintenanceWindow -WindowId $window.WindowId -Force
}

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

$windowId = New-SSMMaintenanceWindow -Name $MWName -Schedule 'cron(0 0/5 * 1/1 * ? *)' -Duration 2 -Cutoff 1 -AllowUnassociatedTarget $true
Write-Verbose "New-SSMMaintenanceWindow WindowId=$windowId"

$a = New-Object 'Amazon.SimpleSystemsManagement.Model.MaintenanceWindowTaskParameterValueExpression'
$a.Values.Add('ifconfig')

$windowTaskId = Register-SSMTaskWithMaintenanceWindow -WindowId $windowId -Target @{Key='InstanceIds';Values=$InstanceIds} `
        -ServiceRoleArn 'arn:aws:iam::660454403809:role/AMIA' `
        -TaskType RUN_COMMAND -TaskArn 'AWS-RunShellScript'  -TaskParameter @{commands=[Amazon.SimpleSystemsManagement.Model.MaintenanceWindowTaskParameterValueExpression]$a} `
        -MaxConcurrency 1 -MaxError 1 -Priority 0
Write-Verbose "Register-SSMTaskWithMaintenanceWindow: WindowTaskId=$windowTaskId"

if ($SetupAction -eq 'SetupOnly') {
    return
}       
        
$cmd = { Get-SSMMaintenanceWindowExecutionList -WindowId $windowId | select -Last 1 }
$execution = Invoke-PSUtilWait -Cmd $cmd 'MW Execution' -RetrySeconds 500 -PrintVerbose -SleepTimeInMilliSeconds 45000
Write-Verbose "WindowExecutionId=$($execution.WindowExecutionId)"

$cmd = {
    $a = Get-SSMMaintenanceWindowExecutionTaskList -WindowExecutionId $execution.WindowExecutionId
    if ($a.Status -notlike '*PROGRESS') {
        $a
    }
}
$taskexecution = Invoke-PSUtilWait -Cmd $cmd 'MW Task Complete' -PrintVerbose
Write-Verbose "TaskExecutionId=$($taskexecution.TaskExecutionId)"

$taskinvocation = Get-SSMMaintenanceWindowExecutionTaskInvocationList -WindowExecutionId $execution.WindowExecutionId -TaskId $taskexecution.TaskExecutionId
Write-Verbose "CommandId=$($taskinvocation.ExecutionId) (TaskInvocation.ExecutionId)"

$command = Get-SSMCommand -CommandId $taskinvocation.ExecutionId
#$taskinvocation 

Test-SSMOuput $command

#Get-SSMMaintenanceWindowExecutionTask -WindowExecutionId $execution.WindowExecutionId -TaskId $taskexecution.TaskExecutionId

Unregister-SSMTaskFromMaintenanceWindow -WindowId $windowId -WindowTaskId $windowTaskId

Remove-SSMMaintenanceWindow -WindowId $windowId -Force
