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


$folder = $PSScriptRoot

$a = aws ec2 create-security-group --group-name sg1 --description "Security group 1" | Out-String | ConvertFrom-Json

aws ec2 describe-security-groups --group-ids $a.GroupId
aws ec2 describe-security-groups --group-name sg1

aws ec2 authorize-security-group-ingress --group-name sg1 --protocol icmp --port all --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name sg1 --protocol tcp --port 3389 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name sg1 --protocol udp --port 3389 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name sg1 --protocol tcp --port 5985-5986 --cidr 0.0.0.0/0


aws ec2 create-key-pair --key-name keypair1 --query 'KeyMaterial' --output text | out-file -encoding ascii -filepath $folder\keypair1.pem
aws ec2 describe-key-pairs --key-name keypair1


$a = aws ec2 describe-images --filters "Name=name,Values=Windows_Server-2012-RTM-English-64Bit-Base*" | Out-String | ConvertFrom-Json
$imageid = $a.Images[0].ImageId

$userdata = @"
<powershell>
Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any
md c:\temp
</powershell>
"@

#$enc = New-Object System.Text.ASCIIEncoding 
#$userdataBase64Encoded = [System.Convert]::ToBase64String($enc.GetBytes($userdata))
#aws ec2 run-instances --image-id $imageid --count 1 --instance-type t1.micro --key-name keypair1 --security-groups sg1  --user-data $userdataBase64Encoded

$a = aws ec2 run-instances --image-id $imageid --count 1 --instance-type t1.micro --key-name keypair1 --security-groups sg1  --user-data "$userdata" | Out-String | ConvertFrom-Json
$instanceid = $a.Instances[0].InstanceId

while ($true)
{
    $a = aws ec2 describe-instances --filters  "Name=instance-id,Values=$instanceid" | Out-String | ConvertFrom-Json
    $publicDNS = $a.Reservations[0].Instances[0].PublicDnsName
    if ($publicDNS -ne $null)
    {
        break
    }
    "$(Get-Date) Waiting for PublicDNSName to be available"
    Sleep 5
}


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

while ($true)
{
    $a = aws ec2 get-password-data --instance-id $instanceid --priv-launch-key $folder\keypair1.pem | Out-String | ConvertFrom-Json
    if ($a.PasswordData -ne $null)
    {
        break
    }

    "$(Get-Date) Waiting for PasswordData to be available"
    Sleep -Seconds 10
}

$securepassword = ConvertTo-SecureString $a.PasswordData -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

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

Invoke-Command -Session $s {Invoke-WebRequest http://169.254.169.254/latest/user-data}
Remove-PSSession $s
#cd WSMan:\localhost\Client
#Set-Item .\TrustedHosts "*" -Force
#dir

aws ec2 stop-instances --instance-ids $instanceid 

while ($true)
{
    $a = aws ec2 describe-instances --instance-ids $instanceid | Out-String | ConvertFrom-Json
    if ($a.Reservations[0].Instances[0].State.Name -eq "Stopped")
    {
        break;
    }
    "$(Get-Date) Waiting to stop"
    Sleep -Seconds 5
}

aws ec2 modify-instance-attribute --instance-id $instanceid --user-data $userdata
$a = aws ec2 describe-instance-attribute --instance-id $instanceid --attribute userData | Out-String | ConvertFrom-Json
$a.UserData.Value #Base64Encoded string
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($a.UserData.Value))

aws ec2 terminate-instances --instance-ids $instanceid

while ($true)
{
    $a = aws ec2 describe-instances --instance-ids $instanceid | Out-String | ConvertFrom-Json
    if ($a.Reservations[0].Instances[0].State.Name -eq "Terminated")
    {
        break;
    }
    "$(Get-Date) Waiting to terminate"
    Sleep -Seconds 5
}


aws ec2 delete-security-group --group-name sg1
aws ec2 delete-key-pair --key-name keypair1


#aws ec2 start-instances --instance-ids $instanceid 
