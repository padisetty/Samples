#Setup once before running any test in this folder.
param ($DefaultRegion = 'us-east-1')

Set-DefaultAWSRegion $DefaultRegion

. "$PSScriptRoot\Common Setup.ps1"

#Remove-WinEC2Instance 'perf*' -NoWait

SSMCreateKeypair -KeyName 'test'
SSMCreateRole -RoleName 'test'
SSMCreateSecurityGroup -SecurityGroupName 'test'
