param ($instance, $cred)
Write-Host "CloudWatch" -ForegroundColor Yellow
Write-Verbose "InstanceId=$($instance.InstanceId)"
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
. .\ssmcommon.ps1

function CMApplyMetrics ($instance)
{
$doc = @"
{
  "schemaVersion": "1.0",
  "description": "Instance configuration",
  "runtimeConfig": {

    "aws:cloudWatch": {
      "description": "Execute demo plugin",
      "properties": {
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
                "DimensionName": "",
                "DimensionValue": ""
              }
            },
            {
              "Id": "CloudWatch",
              "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatch.CloudWatchOutputComponent,AWS.EC2.Windows.CloudWatch",
              "Parameters": {
                "AccessKey": "",
                "SecretKey": "",
                "Region": "us-east-1",
                "NameSpace": "SSMDemo"
              }
            },
            {
              "Id": "CloudWatchLogsForEC2ConfigService",
              "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatchLogsOutput,AWS.EC2.Windows.CloudWatch",
              "Parameters": {
                "Region": "us-east-1",
                "LogGroup": "SSM-Log-Group",
                "LogStream": "{instance_id}"
              }
            },			
            {
			  "Id": "Ec2ConfigETW",
			  "FullName": "AWS.EC2.Windows.CloudWatch.EventLog.EventLogInputComponent,AWS.EC2.Windows.CloudWatch",
			  "Parameters": {
			    "LogName": "EC2ConfigService",
			    "Levels": "7"
			  }
			}
          ],
          "Flows": {
            "Flows": [
              "PerformanceCounter,CloudWatch",
			  "Ec2ConfigETW,CloudWatchLogsForEC2ConfigService"
            ]
          }
        }
      }
    }

  }
}
"@
    Write-Verbose "CMApply instanceid=$($instance.InstanceId)"
    SSMAssociate $instance $doc 
}

function CMApplyLogs ($instance)
{
$doc = @"
{
  "schemaVersion": "1.0",
  "description": "Instance configuration",
  "runtimeConfig": {
    "aws:cloudWatch": {
      "description": "CloudWatch Logs Demo",
      "properties": {
			"EngineConfiguration": {
				"PollInterval": "00:00:15",
				"Components": [
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
							"AccessKey": "",
							"SecretKey": "",
							"Region": "us-east-1",
							"LogGroup": "SSM-Log-Group",
							"LogStream": "{instance_id}"
						}
					}
				],
				"Flows": {
					"Flows": ["SSMLogs,CloudWatchLogs"]
				}
			} 
		}
    }
  }
}
"@
    Write-Verbose "CMApply instanceid=$($instance.InstanceId)"
    SSMAssociate $instance $doc 
}

Get-SSMAssociationList `
    -AssociationFilterList @{key='InstanceId'; Value=$instance.InstanceId} |`
     Remove-SSMAssociation -Force

#CMApplyMetrics -Instance $instance
CMApplyLogs -Instance $instance

