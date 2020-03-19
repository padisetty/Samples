#--------------------------------------------------------------------------------------------
#   Copyright 2014 Sivaprasad Padisetty
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
#   Already have a valid Azure account.
#   Install the PS module from http://www.windowsazure.com/en-us/downloads.
#   Add this is $profile: Import-Module 'C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure'
#
# Run the following cmdlets once per workstation.
#   Get-AzurePublishSettingsFile
#   Import-AzurePublishSettingsFile  'C:\temp\azure.publishsettings’ 
#   In case of multiple subscriptions, select one using Select-AzureSubscription
#   there should current storage account. (e.g.) Get-AzureSubscription | Set-AzureSubscription -CurrentStorageAccountName (Get-AzureStorageAccount).Label
#
# You need to add either publicDNSName or * to make PS remoting work for non domain machines
#    Make sure you understand the risk before doing this
#    Set-Item WSMan:\localhost\Client\TrustedHosts "*" -Force
#    It is better if you add full DNS name instead of *. Because * will match any machine name
# 
# This script focuses on on basic function, does not include security or error handling.
#

param ($instanceType = 'Small')

$image = Get-AzureVMImage | 
            ? label -Like "Windows Server 2012 R2*"  | 
            select -Last 1
$image.Label

$location = Get-AzureLocation | ? Name -EQ 'West US'

$name = "mc-$(Get-Random)"
"Name=$name"

$password = "pass-$(Get-Random)"
"Password=$password"

$startTime = Get-Date
Write-Host "$($startTime) - Creating VM, will take 5+ minutes" -ForegroundColor Green


New-AzureQuickVM -Name $name `
                 -Windows `
                 -ServiceName $name `
                 -Location $location.Name `
                 -ImageName $image.ImageName `
                 -InstanceSize $instanceType `
                 -AdminUsername "siva" `
                 -Password $password `
                 -EnableWinRMHttp  `
                 -WaitForBoot  

$runningTime = Get-Date
Write-Host "$($runningTime) - Running" -ForegroundColor Green

$uri = Get-AzureWinRMUri -Name $name -ServiceName $name
$uri.ToString()

#Skip Certificate Authority check
#This is because of generated certificate with no trusted root
$opts = New-PSSessionOption -SkipCACheck 

#create the securestring
$SecurePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$cred = New-Object PSCredential -ArgumentList "siva", $SecurePassword

do
{
    $processList = Invoke-Command -ConnectionUri $uri `
                   -Credential $cred `
                   -ScriptBlock {Get-Process} `
                   -SessionOption $opts
} while ($processList -eq $null -or $processList.Length -eq 0)

$remoteTime = Get-Date
Write-Host "$($remoteTime) - Remote" -ForegroundColor Green

Remove-AzureService -ServiceName $name -DeleteAll -Force

$terminateTime = Get-Date
Write-Host "$($terminateTime) - Terminate" -ForegroundColor Green

Write-Host "Results"
Write-Host "Azure Instance Type:$instanceType" -ForegroundColor Green
Write-Host "$($runningTime - $startTime) - Running" -ForegroundColor Green
#Write-Host "$($pingTime - $startTime) - Ping" -ForegroundColor Green
#Write-Host "$($passwordTime - $startTime) - Password" -ForegroundColor Green
Write-Host "$($remoteTime - $startTime) - Remote" -ForegroundColor Green
Write-Host "$($terminateTime - $startTime) - Terminate" -ForegroundColor Green
