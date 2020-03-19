<#
    1. Creates a simple lambda function in python
    2. Invokes the functions
    3. Creates the kinesis stream
    4. Create a mapping to invoke function, on a kinesis event
    5. Write event to kinesis stream.
#>


#step 1. Creates a simple lambda function in python
$code = @'
from __future__ import print_function

import json
import base64

print('Loading function....')

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=4))

    if 'Records' in event:
        print('RECORDS:')
        for record in event['Records']:
            payload = base64.b64decode(record['kinesis']['data'])
            #payload = json.load(payload)
            print("Payload: " + payload)
    print("logstream = " + context.log_stream_name)
    return context.log_stream_name  # Echo back the first key value
'@

$codeFile = "$($Env:TEMP)\lambda.py"
$zipFile = "$($Env:TEMP)\lambda.zip"
del $zipFile -ea 0
$functionName = 'PSLambda'

$code | Out-File -Encoding ascii $codeFile

Compress-Archive -Path $codeFile -DestinationPath $zipFile

Get-LMFunctions | ? FunctionName -eq $functionName | Remove-LMFunction -Force

$null = Publish-LMFunction -FunctionZip $zipFile -FunctionName $functionName -Handler 'lambda.lambda_handler' -Role 'arn:aws:iam::660454403809:role/test' -Runtime python2.7

$parameters = @'
{
  "key1": "value1...",
  "key2": "value2"
}
'@

Invoke-PSUtilIgnoreError {Get-CWLLogStreams -LogGroupName /aws/lambda/PSLambda | Remove-CWLLogStream -LogGroupName /aws/lambda/PSLambda -Force}


#
#step 2. Invokes the functions
#
$response = Invoke-LMFunction -FunctionName $functionName -Payload $parameters -InvocationType RequestResponse -LogType Tail 

$json = [System.Text.Encoding]::ASCII.GetString($response.Payload.ToArray())
$logStreamName = ConvertFrom-Json $json
Write-Verbose "Log Stream Name=$logStreamName"

Write-Verbose ''
Write-Verbose 'Log Output:'
$bytes = [System.Convert]::FromBase64String($response.LogResult)
[System.Text.Encoding]::ASCII.GetString($bytes)


#
#step 3. Creates the kinesis stream
#
Register-IAMRolePolicy -RoleName 'test' -PolicyArn 'arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole'

$kinesisStream = 'LamdaTest'

try {
    Remove-KINStream $kinesisStream -Force
} catch {
}

$cmd = {New-KINStream -ShardCount 1 -StreamName $kinesisStream; $true}
$null = Invoke-PSUtilWait -Cmd $cmd -Message "New-KINStream $kinesisStream" -PrintVerbose
$stream = Get-KINStream $kinesisStream


#
#step 4. Create a mapping to invoke function, on a kinesis event
#
$null = Get-LMEventSourceMappings | Remove-LMEventSourceMapping -Force
$cmd = {New-LMEventSourceMapping -FunctionName $functionName -EventSourceArn $stream.StreamARN -StartingPosition TRIM_HORIZON}
$null = Invoke-PSUtilWait -Cmd $cmd -Message "New-LMEventSourceMapping $kinesisStream" -PrintVerbose

$parameters = '{"key": "Kinesis value"}'


#
#step 5. Write event to kinesis stream, and wait till the event is processed
#
$null = Write-KINRecord -StreamName $kinesisStream  -Text $parameters -PartitionKey '1'
$cmd = {
    $mapping = Get-LMEventSourceMappings -FunctionName $functionName
    $mapping.LastProcessingResult -ne 'No records processed'
}
$null = Invoke-PSUtilWait -Cmd $cmd -Message "Event Processing" -PrintVerbose


#Clean up
Get-LMFunctions | ? FunctionName -eq $functionName | Remove-LMFunction -Force
Get-CWLLogStreams -LogGroupName /aws/lambda/PSLambda | Remove-CWLLogStream -LogGroupName /aws/lambda/PSLambda -Force
try {
    Remove-KINStream $kinesisStream -Force
} catch {
}
$null = Get-LMEventSourceMappings | Remove-LMEventSourceMapping -Force
