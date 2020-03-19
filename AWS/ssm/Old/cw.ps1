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
          "description": "CloudWatch Metrics Demo",
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
							    "Region": "us-east-1",
							    "NameSpace": "SSMDemo"
						    }
					    }
				    ],
				    "Flows": {
					    "Flows":["PerformanceCounter,CloudWatch"]
				    }
			    } 
		    }
        }
      }
    }
"@
    Write-Verbose "CMApply instanceid=$($instance.InstanceId)"
    SSMAssociate $instance $doc $cred
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
			              "FullName": "AWS.EC2.Windows.CloudWatch.EventLog.EventLogInputComponent,AWS.EC2.Windows.CloudWatch",
			              "Parameters": {
			                "LogName": "EC2ConfigService",
			                "Levels": "7"
			              }
                        },
					    {
						    "Id": "CloudWatchLogs",
						    "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatchLogsOutput,AWS.EC2.Windows.CloudWatch",
						    "Parameters": {
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
    SSMAssociate $instance $doc  -Credential $cred
}

CMApplyMetrics -Instance $instance
CMApplyLogs -Instance $instance

