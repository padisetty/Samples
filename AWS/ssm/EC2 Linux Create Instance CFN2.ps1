#Uses ASG and can launch multiple instances
# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel

param ($Name = 'ssmlinux', 
        $ParallelIndex,
        $InstanceType = 't2.micro',
        #$ImagePrefix= 'ubuntu/images/hvm-ssd/ubuntu-xenial-16*', 
        $ImagePrefix='amzn-ami-hvm-*gp2', 
        $keyFile = 'c:\keys\test.pem',
        $InstanceCount=2,
        $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
        [string] $SetupAction = ''  # SetupOnly or CleanupOnly
)

$parallelName = "$Name$ParallelIndex"
. $PSScriptRoot\ssmcommon.ps1 $Region

Write-Verbose "EC2 Linux Create Instance Name=$Namme, ImagePrefix=$ImagePrefix, keyFile=$keyFile, InstanceCount=$InstanceCount, Region=$Region, ParallelIndex=$ParallelIndex"

. "$PSScriptRoot\EC2 Terminate Instance.ps1" $parallelName
if ($SetupAction -eq 'CleanupOnly') {
    return
} 

$KeyPairName = 'test'
$RoleName = 'test'
$securityGroup = @((Get-EC2SecurityGroup | ? GroupName -eq 'test').GroupId)
if (Get-EC2SecurityGroup | ? GroupName -eq 'corp') {
    $securityGroup += (Get-EC2SecurityGroup | ? GroupName -eq 'corp').GroupId
}

$image = Get-EC2Image -Filters @{Name = "name"; Values = "$imageprefix*"} | sort -Property CreationDate -Descending | select -First 1

$userdata = @"
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

if [ -f /etc/debian_version ]; then
    echo "Debian"
    curl https://amazon-ssm-$Region.s3.amazonaws.com/latest/debian_amd64/amazon-ssm-agent.deb -o amazon-ssm-agent.deb
    dpkg -i amazon-ssm-agent.deb
else
    echo "Amazon Linux or Redhat"
    curl https://amazon-ssm-$Region.s3.amazonaws.com/latest/linux_amd64/amazon-ssm-agent.rpm -o amazon-ssm-agent.rpm
    yum install -y amazon-ssm-agent.rpm
fi

"@.Replace("`r",'')
$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))

$cnfTemplate = @"
{
	"AWSTemplateFormatVersion": "2010-09-09",
	"Resources": {
		"launchConfig": {
			"Type": "AWS::AutoScaling::LaunchConfiguration",
			"Properties": {
				"ImageId": "$($image.ImageId)",
				"InstanceType": "t2.micro",
				"IamInstanceProfile": "$RoleName",
				"KeyName": "$KeyPairName",
                "SecurityGroups" : $($securityGroup | ConvertTo-Json),
				"UserData": "$userdataBase64Encoded"

			}
		},

		"asg": {
			"Type": "AWS::AutoScaling::AutoScalingGroup",
			"Properties": {
				"LaunchConfigurationName": {
					"Ref": "launchConfig"
				},
				"AvailabilityZones": {
					"Fn::GetAZs": ""
				},
				"MinSize": "$InstanceCount",
				"MaxSize": "$InstanceCount",
				"Tags": [{
					"Key": "Name",
					"Value": "$parallelName",
					"PropagateAtLaunch": "true"
				}]
			}
		}
	}
}
"@


$startTime = Get-Date

$stackId = New-CFNStack -StackName $parallelName -TemplateBody $cnfTemplate
Write-Verbose "CFN StackId=$stackId"

$cmd = { $stack = Get-CFNStack -StackName $parallelName; Write-Verbose "CFN Stack $parallelName Status=$($stack.StackStatus)"; $stack.StackStatus -like '*_COMPLETE'}
$null = Invoke-PSUtilWait -Cmd $cmd -Message 'CFN Stack' -RetrySeconds 300

$stack = Get-CFNStack -StackName $parallelName
if ($stack.StackStatus -ne 'CREATE_COMPLETE') {
    throw "CF Stack Create Failed. Status=$($stack.StackStatus), StackStatusReason=$($stack.StackStatusReason)"
}

$instances = Get-WinEC2Instance $parallelName -DesiredState 'running'
foreach ($instance in $instances) {
    $cmd = { (Get-SSMInstanceInformation -InstanceInformationFilterList @{ Key='InstanceIds'; ValueSet=$instance.InstanceId}).Count -eq 1}
    $null = Invoke-PSUtilWait $cmd 'Instance Registration' 150
}


$obj = @{}
$InstanceIds = $Obj.'InstanceId' = $instances.InstanceId
$obj.'Time' = (Get-Date) - $startTime

return $obj
