#--------------------------------------------------------------------------------------------
#   Copyright 2011 Sivaprasad Padisetty
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http:#www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#--------------------------------------------------------------------------------------------


# Pre requisites
#   Signup for AWS and get the AccessKey & SecretKey. http://docs.aws.amazon.com/powershell/latest/userguide/pstools-appendix-signup.html
#   Read the setup instructions http://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up.html
#   Install PowerShell module from http://aws.amazon.com/powershell/
#
# set the default credentials by calling something below
#   Initialize-AWSDefaults -AccessKey AKIAIOSFODNN7EXAMPLE -SecretKey wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY -Region us-east-1
#
# You need to add either publicDNSName or * to make PS remoting work for non domain machines
#    Make sure you understand the risk before doing this
#    Set-Item WSMan:\localhost\Client\TrustedHosts "*" -Force
#    It is better if you add full DNS name instead of *. Because * will match any machine name
# 
# This script focuses on on basic function, does not include security or error handling.
#
# Since this is focused on basics, it is better to run blocks of code.
#    if you are running blocks of code from ISE PSScriptRoot will not be defined.

function WaitForState ($instanceid, $desiredstate)
{
    while ($true)
    {
        $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid} 
        $state = $a.Instances[0].State.Name
        if ($state -eq $desiredstate)
        {
            break;
        }
        "$(Get-Date) Current State = $state, Waiting for Desired State=$desiredstate"
        Sleep -Seconds 5
    }
}

$folder = "c:\temp" # Location to store some temp stuff like keypair

# PSModule should be autoloaded in PS v3.0 and above
# setup adds AWS module location to the PSModulePath
# To manually load PSModule
# import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"


# To check if AWS PS module is accessible.
# Get-AWSPowerShellVersion -ListServices

#Create the firewall security group, Allows ping traffic, RDP and PowerShell remote connection
$groupid = New-EC2SecurityGroup sg1  -Description "Security group 1"
Get-EC2SecurityGroup -GroupNames sg1
Grant-EC2SecurityGroupIngress -GroupName sg1 -IpPermissions @{IpProtocol = "icmp"; FromPort = -1; ToPort = -1; IpRanges = @("0.0.0.0/0")}
$ipPermissions = New-Object Amazon.EC2.Model.IpPermission
$ipPermissions.IpProtocol = "tcp"
$ipPermissions.FromPort = 3389
$ipPermissions.ToPort = 3389
$ipPermissions.IpRanges.Add("0.0.0.0/0")
Grant-EC2SecurityGroupIngress -GroupName sg1 -IpPermissions $ipPermissions
Grant-EC2SecurityGroupIngress -GroupName sg1 -IpPermissions @{IpProtocol = "udp"; FromPort = 3389; ToPort = 3389; IpRanges = @("0.0.0.0/0")}
Grant-EC2SecurityGroupIngress -GroupName sg1 -IpPermissions @{IpProtocol = "tcp"; FromPort = 5985; ToPort = 5986; IpRanges = @("0.0.0.0/0")}

#create a KeyPair, this is used to encrypt the Administrator password.
$keypair1 = New-EC2KeyPair -KeyName keypair1
"$($keypair1.KeyMaterial)" | out-file -encoding ascii -filepath $folder\keypair1.pem
"KeyName: $($keypair1.KeyName)" | out-file -encoding ascii -filepath $folder\keypair1.pem -Append
"KeyFingerprint: $($keypair1.KeyFingerprint)" | out-file -encoding ascii -filepath $folder\keypair1.pem -Append

#Get-EC2KeyPair keypair1

#Find the Windows Server 2012 imageid
$a = Get-EC2Image -Filters @{Name = "name"; Values = "Windows_Server-2012-RTM-English-64Bit-Base*"}
$imageid = $a.ImageId

#Launch the instance
$userdata = @"
<powershell>
md c:\temp
'Hello a是!' | Out-File 'c:\temp\out.txt'
Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any
Enable-NetFirewallRule FPS-ICMP4-ERQ-In
</powershell>
"@
$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$a = New-EC2Instance -ImageId $imageid -MinCount 1 -MaxCount 1 -InstanceType t1.micro -KeyName keypair1 -SecurityGroups sg1 -UserData $userdataBase64Encoded
$instanceid = $a.Instances[0].InstanceId
WaitForState $instanceid "Running"

$a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid}
$publicDNS = $a.Instances[0].PublicDnsName

#Wait for ping to succeed
while ($true)
{
    ping $publicDNS
    if ($LASTEXITCODE -eq 0)
    {
        break
    }
    "$(Get-Date) Waiting for ping to succeed"
    Sleep -Seconds 10
}

$password = $null
#Wait until the password is available
#blindsly eats all the exceptions, bad idea for a production code.
while ($password -eq $null)
{
    try
    {
        $password = Get-EC2PasswordData -InstanceId $instanceid -PemFile $folder\keypair1.pem -Decrypt
    }
    catch
    {
        "$(Get-Date) Waiting for PasswordData to be available"
        Sleep -Seconds 10
    }
}

$publicDNS, $password

$securepassword = ConvertTo-SecureString $password -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

#Wait until PSSession is available
while ($true)
{
    $s = New-PSSession $publicDNS -Credential $creds 2>$null
    if ($s -ne $null)
    {
        break
    }

    "$(Get-Date) Waiting for remote PS connection"
    Sleep -Seconds 10
}

Invoke-Command -Session $s {(Invoke-WebRequest http://169.254.169.254/latest/user-data).RawContent}

Remove-PSSession $s

#Update user-data
#Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid} | Stop-EC2Instance -Force
#WaitForState $instanceid "Stopped"

#$userdata = @"
#<powershell>
#md c:\temp
#'Hello a是!' | Out-File 'c:\temp\out.txt'
#</powershell>
#"@
#$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))

#Edit-EC2InstanceAttribute -InstanceId $instanceid -UserData $userdataBase64Encoded
#Get-EC2InstanceAttribute -InstanceId $instanceid -Attribute UserData

#Start-EC2Instance -InstanceId $instanceid 
#WaitForState $instanceid "R unning"


#Terminate the Instance
Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid} | Stop-EC2Instance -Force -Terminate
WaitForState $instanceid "Terminated"

Remove-EC2KeyPair -KeyName keypair1 -Force

#There is a timing thing, so has to retry it.
$err = $true
while ($err)
{
    $err = $false
    try
    {
        Remove-EC2SecurityGroup -GroupName sg1 -Force
    }
    catch
    {
        $err = $true
    }
}
