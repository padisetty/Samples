param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmwindows'), 
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1')
    )

Set-DefaultAWSRegion $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
Write-Verbose "Windows RC3 ConfigureCloudWatch: Name=$Name, InstanceId=$instanceIds"


$properties = @"
{
    "EngineConfiguration": {
        "PollInterval": "00:00:15",
        "Components": [
            {
                "Id": "PerformanceCounter",
                "FullName": "AWS.EC2.Windows.CloudWatch.PerformanceCounterComponent.PerformanceCounterInputComponent,AWS.EC2.Windows.CloudWatch",
                "Parameters": {
                    "CategoryName": "Memory",
                    "CounterName": "Available MBytes",
                    "InstanceName": "",
                    "MetricName": "Memory",
                    "Unit": "Megabytes",
                    "DimensionName": "InstanceId",
                    "DimensionValue": "$instanceId"
                }
            },
            {
                "Id": "CloudWatchMetrics",
                "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatch.CloudWatchOutputComponent,AWS.EC2.Windows.CloudWatch",
                "Parameters": {
                    "Region": "$Region",
                    "NameSpace": "SSMDemo"
                }
            },
            {
			    "Id": "SSMLogs",
			    "FullName": "AWS.EC2.Windows.CloudWatch.CustomLog.CustomLogInputComponent,AWS.EC2.Windows.CloudWatch",
			    "Parameters": {
				    "LogDirectoryPath": "C:\\Program Files\\Amazon\\Ec2ConfigService\\Logs",
				    "TimestampFormat": "yyyy-MM-dd HH:mm:ss",
				    "Encoding": "UTF-8",
				    "Filter": "Ec2ConfigPluginFramework*",
				    "CultureName": "en-US",
				    "TimeZoneKind": "Local"
			    }
		    },
		    {
			    "Id": "CloudWatchLogs",
			    "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatchLogsOutput,AWS.EC2.Windows.CloudWatch",
			    "Parameters": {
				    "Region": "$Region",
				    "LogGroup": "SSM-Log-Group",
				    "LogStream": "{instance_id}"
			    }
		    }
        ],
        "Flows": {
            "Flows": [
                "PerformanceCounter,CloudWatchMetrics",
			    "SSMLogs,CloudWatchLogs"
            ]
        }
    }
}
"@

#Run Command
$startTime = Get-Date
$command = SSMRunCommand `
    -InstanceIds $InstanceIds `
    -DocumentName 'AWS-ConfigureCloudWatch' `
    -Parameters @{
        status="Enabled"
        properties=$properties
     } 

$obj = @{}
$obj.'CommandId' = $command

Test-SSMOuput $command -ExpectedMinLength 0

$obj.'CommandId' = $command.CommandId
$obj.'Time' = (Get-Date) - $startTime

return $obj