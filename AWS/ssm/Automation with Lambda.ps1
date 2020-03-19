param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $ParallelIndex,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )
#Automation with Lambda
$parallelName = "$Name$ParallelIndex"

. $PSScriptRoot\ssmcommon.ps1 $Region

$DocumentName = "AutomationWithLambda.$parallelName"
Write-Verbose "DocumentName=$DocumentName, Region=$Region, SetupAction=$SetupAction"

SSMDeleteDocument $DocumentName

if ($SetupAction -eq 'CleanupOnly') {
    return
} 


#step 1. Creates a simple lambda function in python
$code = @'
import json
import base64

import boto3

print('Loading function....')

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=4))

    ec2 = boto3.resource('ec2')

    print('Running Instance list:')
    instances = ec2.instances.filter(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
    for instance in instances:
        print(instance.id, instance.instance_type)
    print('')

    if 'Records' in event:
        print('RECORDS:')
        for record in event['Records']:
            payload = base64.b64decode(record['kinesis']['data'])
            #payload = json.load(payload)
            print("Payload: " + payload)
    print("logstream = " + context.log_stream_name)
    
    return { "LogStream": context.log_stream_name  }
'@

$codeFile = "$($Env:TEMP)\lambda$parallelName.py"
$zipFile = "$($Env:TEMP)\lambda$parallelName.zip"
del $zipFile -ea 0
$functionName = "PSLambda$parallelName"

$code | Out-File -Encoding ascii $codeFile

Compress-Archive -Path $codeFile -DestinationPath $zipFile

Write-Verbose "Delete Lambda function if present, with Name=$functionName"
Get-LMFunctions | ? FunctionName -eq $functionName | Remove-LMFunction -Force


$role = Get-IAMRole 'test'                                                   
$null = Publish-LMFunction -FunctionZip $zipFile -FunctionName $functionName -Handler 'lambda.lambda_handler' -Role $role.Arn -Runtime python3.6
Write-Verbose "Create Python based Lambda function with Name=$functionName"

$payload = '{"key1": "value1...","key2": "value2"}' | ConvertTo-Json

#Invoke-PSUtilIgnoreError {Get-CWLLogStreams -LogGroupName /aws/lambda/$functionName | Remove-CWLLogStream -LogGroupName /aws/lambda/$functionName -Force}

Get-CWLLogGroups /aws/lambda/$functionName | Remove-CWLLogGroup -Force

$doc = @"
{
  "description": "Lambda Function in Automation Service Demo",
  "schemaVersion": "0.3",
  "assumeRole": "arn:aws:iam::660454403809:role/AMIA",
  "mainSteps": [
    {
      "name": "lambda",
      "action": "aws:invokeLambdaFunction",
      "maxAttempts": 1,
      "onFailure": "Continue",
      "inputs": {
        "FunctionName": "$functionName",
        "Payload": $payload,
        "InvocationType": "RequestResponse",
        "LogType" : "Tail"
      }
    }
  ],
  "outputs":["lambda.StatusCode"]
}
"@

$obj = @{}

SSMDeleteDocument -DocumentName $DocumentName

SSMCreateDocument -DocumentName $DocumentName -DocumentContent $doc -DocumentType 'Automation'

$startTime = Get-Date
Write-Verbose "Starting Automation $DocumentName"
$executionid = Start-SSMAutomationExecution -DocumentName $DocumentName 
Write-Verbose "#PSTEST# AutomationExecutionId=$executionid"


$cmd = {$execution = Get-SSMAutomationExecution -AutomationExecutionId $executionid; Write-Verbose "AutomationExecutionStatus=$($execution.AutomationExecutionStatus)"; $execution.AutomationExecutionStatus -eq 'Success'}
$null = Invoke-PSUtilWait -Cmd $cmd -Message 'Automation execution' -RetrySeconds 15 -SleepTimeInMilliSeconds 1000

#Stop-SSMAutomationExecution -AutomationExecutionId $execution

$steps = (Get-SSMAutomationExecution -AutomationExecutionId $executionid).StepExecutions

Write-Verbose "StatusCode=$($steps[0].Outputs.StatusCode)`n"
Write-Verbose "Payload:`n$($steps[0].Outputs.Payload)`n"
Write-Verbose "LogResult:`n$($steps[0].Outputs.LogResult)`n"
$StatusCode=$steps[0].Outputs['StatusCode'][0]
if ($StatusCode -ne 200) {
    throw "StatusCode should be 200, instead it is $StatusCode"
}

$obj.'AutomationExecutionTime' = (Get-Date) - $startTime
$obj.'AutomationExecutionId' = $executionid
$obj

if ($SetupAction -eq 'SetupOnly') {
    return $obj
} 

#delete if present
Remove-SSMDocument -Name $DocumentName -Force

