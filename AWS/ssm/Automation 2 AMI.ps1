$doc = @"
{
  "description": "EC2 Automation Demo - Patch and  Create  New AMI",
  "schemaVersion": "0.3",
  "assumeRole": "arn:aws:iam::660454403809:role/AMIA",
  "parameters": {
      "sourceAMIid": {
          "type": "String",
          "description": "AMI to patch"
      },
    "targetAMIname": {
        "type": "String",
        "description": "name of new AMI"
    }
  },
  "mainSteps": [
    {
      "name": "startInstances",
      "action": "aws:runInstances",
      "timeoutSeconds": 3600,
      "maxAttempts": 1,
      "onFailure": "Continue",
      "inputs": {
        "ImageId": "{{ sourceAMIid }}",
        "MinInstanceCount": 1,
        "MaxInstanceCount": 1,
        "IamInstanceProfileName": "test", 
        "InstanceType":"t2.micro"
      }
    },
    {
      "name": "installMissingWindowsUpdates",
      "action": "aws:runCommand",
      "maxAttempts": 1,
      "onFailure": "Continue",
      "inputs": {
        "DocumentName": "AWS-InstallMissingWindowsUpdates",
        "InstanceIds": ["{{ startInstances.InstanceIds }}"],
        "Parameters": {
          "UpdateLevel": "Important"
        }
      }
    },
    {
      "name":"stopInstance",
      "action": "aws:changeInstanceState",
      "maxAttempts": 1,
      "onFailure": "Continue",
      "inputs": {
        "InstanceIds": ["{{ startInstances.InstanceIds }}"],
        "DesiredState": "stopped"
      }
    },
    {
      "name":"createImage",
      "action": "aws:createImage",
      "maxAttempts": 1,
      "onFailure": "Continue",
      "inputs": {
        "InstanceId": "{{ startInstances.InstanceIds }}",
        "ImageName":  "{{ targetAMIname }}",
        "NoReboot": true,
        "ImageDescription": "Test CreateImage Description"
      }
    },
    {
      "name":"terminateInstance",
      "action": "aws:changeInstanceState",
      "maxAttempts": 1,
      "onFailure": "Continue",
      "inputs": {
        "InstanceIds": ["{{ startInstances.InstanceIds }}"],
        "DesiredState": "terminated"
      }
    }
  ],
  "outputs":["createImage.ImageId"]
}
"@

$DocumentName = 'AMIA1'

SSMDeleteDocument -DocumentName $DocumentName

SSMCreateDocument -DocumentName $DocumentName -DocumentContent $doc -DocumentType 'Automation'

$execution = Start-SSMAutomationExecution -DocumentName $DocumentName -Input @{sourceAMIid='ami-3f0c4628'; targetAMIname='AMI Test'}

Stop-SSMAutomationExecution -AutomationExecutionId $execution


Get-SSMAutomationExecution -AutomationExecutionId $execution | fl *
Get-SSMAutomationExecution -AutomationExecutionId $execution | select -ExpandProperty 'Inputs' 
Get-SSMAutomationExecution -AutomationExecutionId $execution | select -ExpandProperty 'StepExecutions' 
Get-SSMAutomationExecution -AutomationExecutionId $execution | select -ExpandProperty 'Outputs' 


Get-EC2Image -Owner 'self' | Unregister-EC2Image
Get-EC2Snapshot -OwnerId 'self' | Remove-EC2Snapshot -Force