#Setup once before running any test in this folder.
param ($DefaultRegion = 'us-east-1')

Set-DefaultAWSRegion $DefaultRegion

. "$PSScriptRoot\Common Setup.ps1" -SkipDeletingOutput

Remove-WinEC2Instance 'perf*' -NoWait

SSMRemoveRole -RoleName 'test'
SSMRemoveKeypair -KeyName 'test'
SSMRemoveSecurityGroup -SecurityGroupName 'test'