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

ec2-create-group sg1 --description "Security group 1"

ec2-describe-group sg1

ec2-authorize sg1 --protocol icmp --cidr 0.0.0.0/0 --icmp-type-code -1:-1
ec2-authorize sg1 --protocol tcp --port-range 3389 --cidr 0.0.0.0/0
ec2-authorize sg1 --protocol udp --port-range 3389 --cidr 0.0.0.0/0
ec2-authorize sg1 --protocol tcp --port-range 5985-5986 --cidr 0.0.0.0/0

 
ec2-create-keypair keypair1 | out-file -encoding ascii -filepath $folder\keypair1.pem
ec2-describe-keypairs keypair1


$a = ec2-describe-images --all --filter '"name=Windows_Server-2012-RTM-English-64Bit-Base*"'
$imageid = $a[0].Split()[1]  #parse the text to get the id

$userdata = @"
<powershell>
Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any
md c:\temp
</powershell>
"@
$tempfile = [io.path]::GetTempFileName()
$userdata | Out-File -Encoding ascii $tempfile

#$enc = New-Object System.Text.ASCIIEncoding 
#$userdataBase64Encoded = [System.Convert]::ToBase64String($enc.GetBytes($userdata))

$a = ec2-run-instances $imageid --instance-count 1 --instance-type t1.micro --key keypair1 --group sg1  --user-data-file $tempfile
$instanceid = $a[1].Split()[1] 
Remove-Item $tempfile

while ($true)
{
    $a = ec2-describe-instances --filter "`"instance-id=$instanceid`""
    $publicDNS = $a[1].Split()[3] 
    if ($publicDNS -like "*amazonaws.com")
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
    $password = ec2-get-password $instanceid --priv-launch-key $folder\keypair1.pem 2>$null
    if ($password -ne $null)
    {
        break
    }

    "$(Get-Date) Waiting for PasswordData to be available"
    Sleep -Seconds 10
}

$securepassword = ConvertTo-SecureString $password[0] -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

#Need to enable this to trust a non domain joined machine.
#Note: This will overwrites the previous value
#Need to run elevated
#Set-Item WSMan:\localhost\Client\TrustedHosts $publicDNS -Force

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

ec2-stop-instances $instanceid 

while ($true)
{
    $a = ec2-describe-instances $instanceid
    if ($a[1].Split()[5] -eq "Stopped")
    {
        break;
    }
    "$(Get-Date) Waiting to stop"
    Sleep -Seconds 5
}

#don't know how to make it work with new line char
#ec2-modify-instance-attribute $instanceid --user-data $userdata

$a = ec2-describe-instance-attribute $instanceid --user-data
#$a.UserData.Value #Base64Encoded string
#[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($a.UserData.Value))

ec2-terminate-instances $instanceid

while ($true)
{
    $a = ec2-describe-instances $instanceid
    if ($a[1].Split()[5] -eq "Terminated")
    {
        break;
    }
    "$(Get-Date) Waiting to terminate"
    Sleep -Seconds 5
}


ec2-delete-group sg1
ec2-delete-keypair keypair1


#ec2-start-instances --instance-ids $instanceid 
