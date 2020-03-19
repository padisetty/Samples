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
        $InstanceCount=5,
        $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
        [string] $SetupAction = ''  # SetupOnly or CleanupOnly
)

$parallelName = "$Name$ParallelIndex"
. $PSScriptRoot\cfncommon.ps1 $Region

Write-Verbose "EC2 Linux Create Instance Name=$Namme, ImagePrefix=$ImagePrefix, keyFile=$keyFile, InstanceCount=$InstanceCount, Region=$Region, ParallelIndex=$ParallelIndex"

$obj = @{}

CFNDeleteStack $parallelName

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

$cfnTemplate = @"
{
	"AWSTemplateFormatVersion": "2010-09-09",
	"Resources": {
		"$parallelName" : {
  	        "Type" : "AWS::EC2::Instance",
   	        "Properties" : {
	  	        "ImageId" : "$($image.ImageId)",
	  	        "InstanceType" : "t2.micro",
		        "IamInstanceProfile" : "$RoleName",
		        "NetworkInterfaces" : [ {
			        "DeviceIndex" : "0",
			        "AssociatePublicIpAddress" : "true",
                    "GroupSet" : $($securityGroup | ConvertTo-Json)
		        } ],
		        "KeyName" : "$KeyPairName",
                 "Tags" : [{
                          "Key"   : "Name",
                          "Value" : "$parallelName"
                        }],
                 "UserData": "$userdataBase64Encoded"
	        }
       }
	}
}
"@

$stack = CFNCreateStack -StackName $parallelName -TemplateBody $cfnTemplate -obj $obj
$obj.'StackId' = $stack.stackId

CFNDeleteStack -StackName $parallelName -obj $obj

return $obj