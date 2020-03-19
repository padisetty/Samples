# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel


param ($Name = 'cfn', 
        $ParallelIndex,
        $Count=2,
        $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
        [string] $SetupAction = ''  # SetupOnly or CleanupOnly
)

$parallelName = "$Name$ParallelIndex"
. $PSScriptRoot\cfncommon.ps1 $Region

Write-Verbose "SAM: Name=$Namme, ParallelIndex=$ParallelIndex, Count=$Count, Region=$Region, SetupAction=$SetupAction"
CFNDeleteStack $parallelName

$bucket = Get-SSMS3Bucket
$keyprefix = "cfn/SAM/$parallelName/SourceCode.zip"
Write-Verbose "Bucket=$bucket, Key=$keyprefix"

$null = Get-S3Object -BucketName $bucket -KeyPrefix $keyprefix | Remove-S3Object -Force

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

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
$code | Out-File -Encoding ascii $codeFile

Compress-Archive -Path $codeFile -DestinationPath $zipFile
Write-S3Object -BucketName $bucket -Key $keyprefix -File $zipFile

$cfnTemplate = @"
Transform: AWS::Serverless-2016-10-31
Resources:
  ServerlessFunctionLogicalID:
    Type: AWS::Serverless::Function
    Properties:
      Handler: lambda.lambda_handler
      Runtime: python3.6
      CodeUri: 's3://$bucket/$keyprefix'
"@

$obj = @{}

$stack = CFNCreateStackWithChangeSet -StackName $parallelName -TemplateBody $cfnTemplate -obj $obj
$obj.'StackId' = $stack.stackId

CFNDeleteStack -StackName $parallelName -obj $obj

return $obj