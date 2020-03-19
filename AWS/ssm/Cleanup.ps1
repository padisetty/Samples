#Setup once before running any test in this folder.
param ($DefaultRegion = 'us-east-1')

Set-DefaultAWSRegion $DefaultRegion

#. "$PSScriptRoot\Common Setup.ps1" -SkipDeletingOutput

SSMRemoveRole -RoleName 'test'
SSMRemoveKeypair -KeyName 'test'
SSMRemoveSecurityGroup -SecurityGroupName 'test'
Get-SSMAssociationList | % { Remove-SSMAssociation -AssociationId $_.AssociationId -Force }
