param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $ParallelIndex,
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )

. $PSScriptRoot\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
if ($InstanceIds -isnot [System.Array]) {
    $InstanceIds = ,$InstanceIds
}

Write-Verbose "Automation 1 Run Command: Name=$Name, InstanceIds=$instanceIds"

$doc = @"
{
  "description": "EC2 Run Command in Automation Service Demo",
  "schemaVersion": "0.3",
  "assumeRole": "arn:aws:iam::660454403809:role/AMIA",
  "mainSteps": [
    {
      "name": "run",
      "action": "aws:runCommand",
      "maxAttempts": 1,
      "onFailure": "Continue",
      "inputs": {
        "DocumentName": "AWS-RunShellScript",
        "InstanceIds": $(ConvertTo-Json $instanceIds),
        "Parameters": {
            "commands" : "ifconfig"
        }
      }
    }
  ],
  "outputs":["run.CommandId"]
}
"@

$parallelName = "$Name$ParallelIndex"
$DocumentName = "AutomationWithRunCommand-$parallelName"

SSMDeleteDocument -DocumentName $DocumentName

if ($SetupAction -eq 'CleanupOnly') {
    return
} 


SSMCreateDocument -DocumentName $DocumentName -DocumentContent $doc -DocumentType 'Automation'

$executionid = Start-SSMAutomationExecution -DocumentName $DocumentName
Write-Verbose "#PsTest# AutomationExecutionId=$executionid"


$cmd = {
    $execution = Get-SSMAutomationExecution -AutomationExecutionId $executionid
    Write-Verbose "AutomationExecutionStatus=$($execution.AutomationExecutionStatus)"
    $execution.AutomationExecutionStatus -eq 'Success'
}
$null = Invoke-PSUtilWait -Cmd $cmd -Message 'Automation execution' -RetrySeconds 60 -SleepTimeInMilliSeconds 2000

#Stop-SSMAutomationExecution -AutomationExecutionId $execution

$a = Get-SSMAutomationExecution -AutomationExecutionId $executionid

$steps = (Get-SSMAutomationExecution -AutomationExecutionId $executionid).StepExecutions

$commandId = $steps[0].Outputs['CommandId'][0]
Write-Verbose "CommandId=$commandId"

if ($commandId -ne $a.Outputs['run.CommandId']) {
    throw "CommandId from Outputs did not match. Step CommandId=$commandId, Output CommandId=$($a.Outputs['run.CommandId'])"
}

$command = Get-SSMCommand -CommandId $commandId


$obj = @{}
$obj.'CommandId' = $command.CommandId
$obj.'AutomationExecutionId' = $executionid


Test-SSMOuput $command

$obj
if ($SetupAction -eq 'SetupOnly') {
    return
} 

#delete Document
SSMDeleteDocument -DocumentName $DocumentName
