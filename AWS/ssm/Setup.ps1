#Setup once before running any test in this folder.
param ($Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'))

. $PSScriptRoot\ssmcommon.ps1 $Region

SSMCreateKeypair -KeyName 'test'
SSMCreateRole -RoleName 'test'
SSMCreateSecurityGroup -SecurityGroupName 'test'

