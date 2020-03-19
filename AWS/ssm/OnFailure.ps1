param (
    $PsTestObject = $obj,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1' 4>$null)
)

. $PSScriptRoot\ssmcommon.ps1
Set-DefaultAWSRegion $Region

Write-Verbose ''
Write-Verbose 'Relevent Information:'

function SSMGetInstanceInformation ($InstanceIds) {
    $instances = Get-WinEC2Instance -NameOrInstanceIds ($InstanceIds -join ',') -DesiredState '*' 4>$null
    Write-Verbose ''
    Write-Verbose "SSMGetInstanceInformation: InstanceIds=$InstanceIds, retreived count=$($instances.Count)"

    foreach ($instance in $Instances) {
        Write-Verbose "  InstanceId=$($instance.InstanceId), Platform=$($instance.PlatformName), State=$($instance.State), SSMStatus=$($instance.SSMPingStatus), AgentVersion=$($instance.AgentVersion)"
    }
}

if ($PsTestObject.InstanceIds) {
    SSMGetInstanceInformation $PsTestObject.InstanceIds
}

if ($PsTestObject.CommandId) {
    SSMGetCommandInformation $PsTestObject.CommandId
}
if ($PsTestObject.AssociationId) {
    SSMGetAssociationInformation -AssociationId $PsTestObject.AssociationId -instanceIds $PsTestObject.InstanceIds
}
if ($PsTestObject.AutomationExecutionId) {
    SSMGetAutomationExecutionInformation $PsTestObject.AutomationExecutionId
}

if ($PsTestObject.InstanceIds) {
#    foreach ($instanceId in $PsTestObject.InstanceIds.Split(',')) {
    foreach ($instanceId in $PsTestObject.InstanceIds) {
        Write-Verbose ''
        $instance = Get-WinEC2Instance $instanceId 4>$null

        if ($instance) {
            #Write-Verbose "Console log for InstanceId=$instanceId is:"
            #Get-WinEC2ConsoleOutput $instance.InstanceId  | Write-Verbose

            $user = 'ec2-user'
            $keyFile = 'c:\keys\test.pem'
            Write-Verbose ''
            Write-Verbose "ssm-agent.log for InstanceId=$instanceId is:"
            Invoke-WinEC2Command -InstancesOrNameOrInstanceIds $instance -Script 'if [ -f /var/log/amazon/ssm/amazon-ssm-agent.log ]; then sudo cat /var/log/amazon/ssm/amazon-ssm-agent.log; fi'
        } else {
            Write-Warning "Instance for InstanceId=$instanceId not found"
        }
        #Invoke-PsUtilSSHCommand -key $keyFile -user $user -remote $Instance.PublicIpAddress -port 22 -cmd 'sudo cat /var/log/amazon/ssm/amazon-ssm-agent.log' | Write-Verbose
    }
}