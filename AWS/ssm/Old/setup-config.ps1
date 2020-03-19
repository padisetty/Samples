Set-DefaultAWSRegion 'us-east-1'
#$VerbosePreference='Continue'
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'

cd $PSScriptRoot
. .\ssmcommon.ps1

#Define which accounts or AWS services can assume the role.
$assumePolicy = @"
{
    "Version":"2012-10-17",
    "Statement":[
      {
        "Sid":"",
        "Effect":"Allow",
        "Principal":{"Service":"ec2.amazonaws.com"},
        "Action":"sts:AssumeRole"
      }
    ]
}
"@

# Define which API actions and resources the application can use 
# after assuming the role
$policy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAccessToSSM",
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeAssociations",
        "ssm:ListAssociations",
        "ssm:GetDocument",
        "ssm:UpdateAssociationStatus",
        "ds:CreateComputer",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "cloudwatch:PutMetricData"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
"@

$index = '1'
if ($psISE -ne $null)
{
    #Role name is suffixed with the index corresponding to the ISE tab
    #Ensures to run multiple scripts concurrently without conflict.
    $index = $psISE.CurrentPowerShellTab.DisplayName.Split(' ')[1]
}
#Create the role, write the rolepolicy
$role = 'role' + $index
$null = New-IAMRole -RoleName $role -AssumeRolePolicyDocument $assumePolicy
Write-IAMRolePolicy -RoleName $role -PolicyDocument $policy -PolicyName 'ssm'

#Create instance profile and add the above created role
$null = New-IAMInstanceProfile -InstanceProfileName $role
Add-IAMRoleToInstanceProfile -InstanceProfileName $role -RoleName $role


$d = Get-DSDirectory | select -First 1
function checkSubnet ([string]$cidr, [string]$ip)
{
    $network, [int]$subnetlen = $cidr.Split('/')
    $a = [uint32[]]$network.split('.')
    [uint32] $unetwork = ($a[0] -shl 24) + ($a[1] -shl 16) + ($a[2] -shl 8) + $a[3]
    $mask = (-bnot [uint32]0) -shl (32 - $subnetlen)
    $a = [uint32[]]$ip.split('.')
    [uint32] $uip = ($a[0] -shl 24) + ($a[1] -shl 16) + ($a[2] -shl 8) + $a[3]
    $unetwork -eq ($mask -band $uip)
}
$subnet = Get-EC2Subnet | ? { checkSubnet $_.CidrBlock $d.DnsIpAddrs[0]} | select -First 1
$subnet = Get-EC2Subnet | select -First 1

#create keypair
$keyName = 'ssm-demo-key' + $index
$keypair = New-EC2KeyPair -KeyName $keyName
$dir = pwd
$keyfile = "$dir\$keyName.pem"
"$($keypair.KeyMaterial)" | Out-File -encoding ascii -filepath $keyfile

#Create Security Group
#Security group and the instance should be in the same network (VPC)
$securityGroupName = 'ssm-demo-sg' + $index
$securityGroupId = New-EC2SecurityGroup $securityGroupName  -Description "SSM Demo" -VpcId $subnet.VpcId

$bytes = (Invoke-WebRequest 'http://checkip.amazonaws.com/').Content
$SourceIPRange = @(([System.Text.Encoding]::Ascii.GetString($bytes).Trim() + "/32"))
Write-Verbose "$sourceIPRange retreived from checkip.amazonaws.com"

$fireWallPermissions = @(
    @{IpProtocol = 'tcp'; FromPort = 3389; ToPort = 3389; IpRanges = $SourceIPRange},
    @{IpProtocol = 'tcp'; FromPort = 5985; ToPort = 5986; IpRanges = $SourceIPRange},
    @{IpProtocol = 'tcp'; FromPort = 80; ToPort = 80; IpRanges = $SourceIPRange},
    @{IpProtocol = 'icmp'; FromPort = -1; ToPort = -1; IpRanges = $SourceIPRange}
)

Grant-EC2SecurityGroupIngress -GroupId $securityGroupId `
    -IpPermissions $fireWallPermissions 

#Get the latest R2 base image
$image = Get-EC2ImageByName WINDOWS_2012R2_BASE

#User Data to enable PowerShell remoting on port 80
#User data must be passed in as 64bit encoding.
$userdata = @"
<powershell>
Enable-NetFirewallRule FPS-ICMP4-ERQ-In
Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any
New-NetFirewallRule -Name "WinRM80" -DisplayName "WinRM80" -Protocol TCP -LocalPort 80
Set-Item WSMan:\localhost\Service\EnableCompatibilityHttpListener -Value true
</powershell>
"@
$utf8 = [System.Text.Encoding]::UTF8.GetBytes($userdata)
$userdataBase64Encoded = [System.Convert]::ToBase64String($utf8)

#Launch EC2 Instance with the role, firewall group created
# and on the right subnet
$instance = (New-EC2Instance -ImageId $image.ImageId `
                -InstanceProfile_Id $role `
                -AssociatePublicIp $true `
                -SecurityGroupId $securityGroupId `
                -SubnetId  $subnet.SubnetId `
                -KeyName $keyName `
                -UserData $userdataBase64Encoded `
                -InstanceType 'c3.large').Instances[0]

#Wait to retrieve password
$cmd = { 
        $password = Get-EC2PasswordData -InstanceId $instance.InstanceId `
            -PemFile $keyfile -Decrypt 
        $password -ne $null
        }
SSMWait $cmd 'Password Generation' 600

$password = Get-EC2PasswordData -InstanceId $instance.InstanceId `
            -PemFile $keyfile -Decrypt 
$securepassword = ConvertTo-SecureString $Password -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

#update the instance to get the public IP Address
$instance = (Get-EC2Instance $instance.InstanceId).Instances[0]

#Wait for remote PS connection
$cmd = {
    icm $instance.PublicIpAddress {dir c:\} -Credential $creds -Port 80 
}
SSMWait $cmd 'Remote Connection' 450

New-EC2Tag -ResourceId $instance.InstanceId -Tag @{Key='Name'; Value=$role}

#Cloud Watch
& .\cw.ps1 $instance $creds

#MSI Application to insall 7-zip
& .\7zip.ps1 $instance $creds

#PowerShell module
function PSUtilZipFolder(
    $SourceFolder, 
    $ZipFileName, 
    $IncludeBaseDirectory = $true)
{
    del $ZipFileName -ErrorAction 0
    Add-Type -Assembly System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder,
        $ZipFileName, [System.IO.Compression.CompressionLevel]::Optimal, 
        $IncludeBaseDirectory)
}

PSUtilZipFolder -SourceFolder "$dir\PSDemo" `
    -ZipFileName "$dir\PSDemo.zip" -IncludeBaseDirectory $false
write-S3Object -BucketName 'sivabuckets3' -key 'public/PSDemo.zip' `
    -File .\PSDemo.zip -PublicReadOnly
del .\PSDemo.zip 

& .\psmodule.ps1 $instance $creds

#Domain Join
& .\dj.ps1 $instance $creds

#Cleanup
#Terminate the instance
$null = Stop-EC2Instance -Instance $instance.InstanceId -Force -Terminate

#Remove Association and Document Cleanup
$association = Get-SSMAssociationList -AssociationFilterList `
                @{Key='InstanceId'; Value=$instance.instanceid}
if ($association)
{
    Remove-SSMAssociation -InstanceId $association.InstanceId `
        -Name $association.Name -Force
    Remove-SSMDocument -Name $association.Name -Force
}

#Remove the instance role and IAM Role
Remove-IAMRoleFromInstanceProfile -InstanceProfileName $role `
    -RoleName $role -Force
Remove-IAMInstanceProfile $role -Force
Remove-IAMRolePolicy $role ssm -Force
Remove-IAMRole $role -Force

#delete keypair
del $keyfile -ea 0
Remove-EC2KeyPair -KeyName $keyName -Force

#To deal with timing, SSMWait is used.
SSMWait {(Remove-EC2SecurityGroup $securityGroupId -Force) -eq $null} `
        'Delete Security Group' 150
