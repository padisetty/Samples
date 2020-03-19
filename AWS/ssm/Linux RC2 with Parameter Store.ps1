param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $ParallelIndex,
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion).Region -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )

. $PSScriptRoot\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}

$parallelName = "$Name$ParallelIndex"
$documentName = "ParameterStoreReference-$parallelName"
$parameters = @("test$($parallelName)hello", "production$($parallelName)hello")

$parameters = @(
    @{
        Name = "/Config$($parallelName)/app1/test/s3bucket"
        Value = 'test_s3bucket'
        Type = 'String'
    }
    @{
        Name = "/Config$($parallelName)/app1/test/dbpassword"
        Value = 'test_dbpassword'
        Type = 'SecureString'
    }
    @{
        Name = "/Config$($parallelName)/app1/production/s3bucket"
        Value = 'production_s3bucket'
        Type = 'String'
    }
    @{
        Name = "/Config$($parallelName)/app1/production/dbpassword"
        Value = 'production_dbpassword'
        Type = 'SecureString'
    }
)

Write-Verbose "Linux RC3 with Parameter Store: InstanceIds=$InstanceIds, DocumentName=$DocumentName"

$doc = @"
{
    "schemaVersion": "2.0",
    "description": "Sample Document shows Parameters based on environment",
    "parameters":{
        "environment":{
            "type":"String",
            "description":"(Optional) Define the environment name.",
            "displayType":"textarea",
            "default": "test",
            "allowedValues":[
                            "test",
                            "production"
                        ]
        },
        "s3bucket":{
            "type":"String",
            "description":"(Optional) Fetched from parameter store based on environment",
            "displayType":"textarea",
            "default": "{{ssm:/Config$($parallelName)/app1/test/s3bucket}}"
        }
    },
    "mainSteps": [
        {
            "action": "aws:runShellScript",
            "name": "run",
            "inputs": {
                "runCommand": [
                    "echo environment = {{ environment }}",
                    "echo s3bucket = {{ s3bucket }}"
                 ]
            }
        }
    ]
}
"@

#$doc
#return

#            "default": "{{ssm:{{environment}}-$parallelName-hello}}"


function Cleanup () {
    SSMDeleteDocument $DocumentName
    foreach ($parameter in $parameters) {
        if (Get-SSMParameterList -Filter @{Key='Name';Values=$parameter.Name}) {
            Remove-SSMParameter -Name $parameter.Name -Force
        }
    }
}
Cleanup

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

SSMCreateDocument $DocumentName $doc
Write-Verbose (Get-SSMDocument -Name $documentName).Content
foreach ($parameter in $parameters) {
    Write-Verbose "Create SSM Parameter Name=$($parameter.Name), Value=$($parameter.Value), Type=$($parameter.Type)"
    Write-SSMParameter -Name $parameter.Name -Value $parameter.Value -Type $parameter.Type
}

$startTime = Get-Date
$command = SSMRunCommand -InstanceIds $InstanceIds -SleepTimeInMilliSeconds 1000 `
    -DocumentName $DocumentName -Parameters @{environment='test'}

Test-SSMOuput $command -ExpectedOutput 'test_s3bucket' -ExpectedMinLength 10 

Write-Verbose "Time = $((Get-Date) - $startTime)"

if ($SetupAction -eq 'SetupOnly') {
    return
}

Cleanup