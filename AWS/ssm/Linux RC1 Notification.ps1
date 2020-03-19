param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue "ssmlinux"), 
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
$parallelName = "$Name$ParallelIndex"
#$bucket = 'sivaiadbucket'
$bucket = Get-SSMS3Bucket
$keyprefix = "ssm/snsteset/$parallelName"
$functionName = "PSLambda$parallelName"
Write-Verbose "Linux RC Notification: Name=$Name, InstanceId=$instanceIds. parallelName=$parallelName"

$null = Get-S3Object -BucketName $bucket -KeyPrefix $keyprefix | Remove-S3Object -Force


Invoke-PSUtilIgnoreError {Get-SQSQueue | where { $_ -like "*:$parallelName-*"} | Remove-SQSQueue -Force}
Get-SNSTopic| ? { $_.TopicArn -like "*:$parallelName-*" } | Remove-SNSTopic -Force

#add a random number to speed up, otherwise we have to wait for 60 seconds to create with same name
$parallelNameRandom = "$parallelName-$(Get-Random)"

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

#
#Notification setup for SSM to send SNS notification
#

$role = Get-IAMRole 'test'                                                   

Write-Verbose "Create SNS Topic $parallelNameRandom"
$topic = New-SNSTopic -Name $parallelNameRandom
Write-Verbose "Created SNS Topic=$topic"

####### SQS

Write-Verbose "Create SQS Queue $parallelNameRandom"
$sqs = Invoke-PSUtilWait -cmd {New-SQSQueue $parallelNameRandom} -Message 'Create SQS' -RetrySeconds 120 -ExceptionFilter '*You must*' # can't be recreated right after delete, need to wait for 60 sec
$sqsArn = (Get-SQSQueueAttribute $sqs -AttributeName 'QueueArn').QueueARN
Write-Verbose "QueueUrl=$sqs, Arn=$sqsArn"

$subscriptionArn = Connect-SNSNotification -Endpoint $sqsArn -Protocol 'sqs' -TopicArn $topic

$policy = @"
{
  "Version": "2012-10-17",
  "Id": "$sqsArn/SQSDefaultPolicy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "SQS:SendMessage",
      "Resource": "$sqsArn",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "$topic"
        }
      }
    }
  ]
}
"@

Write-Verbose "Set-SQSQueueAttribute QueueUrl=$sqs"
Set-SQSQueueAttribute -QueueUrl $sqs -Attribute @{ Policy = $policy }

$ownerId = (Get-EC2SecurityGroup -GroupNames "default")[0].OwnerId
Add-SQSPermission -Action 'SendMessage' -QueueUrl $sqs -Label 'queue-permission' -AWSAccountId $ownerId 


########## Lambda
Get-CWLLogGroups /aws/lambda/$functionName | Remove-CWLLogGroup -Force

$code = @"
import boto3
import json

print('Loading function')

def lambda_handler(event, context):
    message = event['Records'][0]['Sns']['Message']
    print("From SNS: " + message)

    jsonmessage = json.loads(message)
    bucket="$bucket"

    if "instanceId" in jsonmessage:
        s3key = "$keyprefix/" + jsonmessage["instanceId"] + ".txt"
    else:
        s3key = "$keyprefix/" + jsonmessage["commandId"] + ".txt"
    print("S3 Bucket=" + bucket)
    print("S3 Key=" + s3key)

    s3 = boto3.resource('s3')

    objs = list(s3.Bucket(bucket).objects.filter(Prefix=s3key))
    if len(objs) > 0 and objs[0].key == s3key:
        s3key = s3key + ".duplicate.txt"

    object = s3.Object(bucket, s3key)
    object.put(Body=message)

    return message
"@

$filename = "lambda$parallelName"
$codeFile = "$($Env:TEMP)\$filename.py"
$zipFile = "$($Env:TEMP)\$filename.zip"
del $zipFile -ea 0

$code | Out-File -Encoding ascii $codeFile

Compress-Archive -Path $codeFile -DestinationPath $zipFile

Write-Verbose "Delete Lambda function if present, with Name=$functionName"
Get-LMFunctions | ? FunctionName -eq $functionName | Remove-LMFunction -Force

$result = Publish-LMFunction -FunctionZip $zipFile -FunctionName $functionName -Handler "$filename.lambda_handler" -Role $role.Arn -Runtime python3.6
Write-Verbose "Create Python based Lambda function with Name=$functionName"

$null = Add-LMPermission -FunctionName $functionName -StatementId $parallelName -Action 'lambda:InvokeFunction' -Principal "sns.amazonaws.com" -SourceArn $topic

$subscriptionArn = Connect-SNSNotification -Endpoint $result.FunctionArn -Protocol 'lambda' -TopicArn $topic


function getMessage ($sqs) {
    $message = Receive-SQSMessage -QueueUrl $sqs -WaitTimeInSeconds 15 -VisibilityTimeout 10 -AttributeName All

    if ($message) {
        $json = ConvertFrom-Json (ConvertFrom-Json $message.Body).Message
        Write-Verbose "`n`nReceived MessageId=$($message.MessageId)`nExpectedCommandId=$expectedCommandId`n$(Get-PSUtilStringFromObject $message.Attributes)`nbody=$json"

        Remove-SQSMessage -QueueUrl $sqs -ReceiptHandle $message.ReceiptHandle -Force 
        Write-Verbose "Removed Message: CommandId=$($json.commandId), InstanceId=$($json.InstanceId)"
    }
    return $json
}

function receiveMessage ($sqs, $expectedCommandId, $expectedDocumententName, $expectedStatus)
{
    for ($i=0; $i -lt 15; $i++) {
        Write-Verbose "receive Message Iteration #$i"
        $json = getMessage $sqs
        if (-not $json) {
            continue
        }

        if ($expectedCommandId -ne $json.commandId) {
            Write-Error "Unexpected commandId, Received CommandId=$($json.commandId), Expected=$expectedCommandId"
            #continue
        }

        if ($expectedCommandId -ne $json.commandId -or $expectedDocumententName -ne $json.documentName -or $expectedStatus -ne $json.status) {
            throw "Did not match with EXPECTED: CommandId=$expectedCommandId, DocumententName=$expectedDocumententName, Status=$expectedStatus"
        }

        return
    }
    throw "Receive Message Failed: EXPECTED: CommandId=$expectedCommandId, DocumententName=$expectedDocumententName, Status=$expectedStatus"
}


function queueShouldBeEmpty ($sqs)
{
    $err = $null
    $json = getMessage $sqs
    if ($json) {
        $err = "Unexpected extra sqs message, Queue should be empty"
        Write-Verbose $err
    } else {
        Write-Verbose 'Queue is empty as expected'
    }
    return $err
}

function checkS3Key ($key) {
    $err = $null
    $objs = Invoke-PSUtilWait -cmd {Get-S3Object -BucketName $bucket -KeyPrefix $key} -Message "S3 Key" -RetrySeconds 120
    
    $filename = "$($Env:TEMP)\$parallelName.txt"
    foreach ($obj in $objs) {
        Write-Verbose "S3 Bucket=$bucket, Key=$($obj.Key)"
        $st = Read-S3Object -BucketName $bucket -Key $obj.Key -File $filename
        Write-Verbose (cat $filename)
    }
    del $filename -EA 0

    if (! $objs) {
        $err = "Lambda was not executed. Key=$key"
        Write-Verbose $err
    }

    if ($objs.Count -eq 1) {
        $null = Remove-S3Object -BucketName $bucket -Key $objs.Key -Force
        Write-Verbose "Removed s3 key=$($objs.Key)"
    } else {
        $objs.Key | Write-Verbose
        $err = "Duplicate found, (i.e.) Lambda was executed multiple times for same event. Actual Count=$($objs.Count), Key=$key"
        Write-Verbose $err
    }
    
    return $err
}


#
#Run Command with invocation notification
#
for ($i=0; $i -lt 3; $i++) {
    Write-Verbose ''
    Write-Verbose "Invocation Notification: #$i Sending Command ifconfig InstanceId=$InstanceIds"
    $command = Send-SSMCommand -InstanceIds $InstanceIds -DocumentName 'AWS-RunShellScript' -Parameters @{commands='ifconfig'} `
                  -NotificationConfig_NotificationArn $topic `
                  -NotificationConfig_NotificationType Invocation `
                  -NotificationConfig_NotificationEvent @('Success', 'TimedOut', 'Cancelled', 'Failed') `
                  -ServiceRoleArn $role.Arn
    Write-Verbose "#$i Sending Command ifconfig CommandId=$($command.CommandId), InstanceId=$InstanceIds"

    foreach ($instanceid in $InstanceIds) {
        receiveMessage -sqs $sqs -expectedCommandId $command.CommandId -expectedDocumententName 'AWS-RunShellScript' -expectedStatus 'Success'
    }
    $errs = ''
    $err = queueShouldBeEmpty -sqs $sqs
    if ($err) {
       $errs += "$err`n"
    }

    foreach ($instanceid in $InstanceIds) {
        $err = checkS3Key("$keyprefix/$instanceid") 
        if ($err) {
           $errs += "$err`n"
        }
    }
    if ($errs.Length -gt 0) {
        throw $errs
    }

    #Test-SSMOuput $command 
}

#
#Run Command with Command notification
#
for ($i=0; $i -lt 3; $i++) {
    Write-Verbose ''
    Write-Verbose "Command Notification: #$i Sending Command ifconfig InstanceId=$InstanceIds"
    $command = Send-SSMCommand -InstanceIds $InstanceIds -DocumentName 'AWS-RunShellScript' -Parameters @{commands='ifconfig'} `
                  -NotificationConfig_NotificationArn $topic `
                  -NotificationConfig_NotificationType Command `
                  -NotificationConfig_NotificationEvent @('Success', 'TimedOut', 'Cancelled', 'Failed') `
                  -ServiceRoleArn $role.Arn
    Write-Verbose "Sending Command ifconfig CommandId=$($command.CommandId), InstanceId=$InstanceIds"

    receiveMessage -sqs $sqs -expectedCommandId $command.CommandId -expectedDocumententName 'AWS-RunShellScript' -expectedStatus 'Success'
    $errs = ''
    $err = queueShouldBeEmpty -sqs $sqs
    if ($err) {
       $errs += "$err`n"
    }

    $err = checkS3Key("$keyprefix/$($command.CommandId)") 
    if ($err) {
        $errs += "$err`n"
    }
    if ($errs.Length -gt 0) {
        throw $errs
    }
    #Test-SSMOuput $command 
}

#
#Notification cleanup
#
Remove-SQSQueue -QueueUrl $sqs -Force
Write-Verbose "Removed SQSQueue $sqs"

Remove-SNSTopic $topic -Force
Write-Verbose "Removed SNSTopic $topic"

return $obj