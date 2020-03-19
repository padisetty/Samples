param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = '',  # SetupOnly or CleanupOnly
    [string] $DocumentName = $null, # = 'AWS-RunShellScript',
    [Hashtable] $Parameters = $null, #@{commands=@('ifconfig')},
    [string] $AssocinationName = "$DocumentName-$Name",
    [string] $Schedule = "cron(0 0 0 ? * SUN *)"
    )

. $PSScriptRoot\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $instances = Get-WinEC2Instance $Name -DesiredState 'running'
    $InstanceIds = $instances.InstanceId
} else {
    $instances = Get-WinEC2Instance ($InstanceIds -join ',')
}

Write-Verbose "Associate 1: InstanceIds=$($instances.InstanceId), DocumentName=$DocumentName, AssociationName=$AssocinationName"

SSMDeleteAssociation -AssociationName $AssocinationName

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

if ((Get-Random) % 3 -eq 0) { # favors Tag based.
    Write-Verbose 'Associate with InstanceID'
    $targets = @{Key='instanceids';Values=$instances.InstanceId}
} else {
    Write-Verbose 'Associate with Tag'
    $targets = @{Key='tag:Name';Values=$Name}
}

$associationId = (SSMAssociateTarget -AssociationName $AssocinationName -DocumentName $DocumentName -Targets $targets -Parameters $Parameters -Schedule $Schedule).Associationid
Write-Verbose "#PSTEST# AssociationId=$associationId"

#SSMWaitForMapping -InstanceIds $instances.InstanceId -AssociationCount 1 -AssociationId $associationId
#SSMRefreshAssociation $instances.InstanceId
SSMWaitForAssociation -InstanceId $instances.InstanceId -ExpectedAssociationCount 1 -MinS3OutputSize 13 -AssociationId $associationId

@{AssociationID = $associationId}

if ($SetupAction -eq 'SetupOnly') {
    return
}

SSMDeleteAssociation -AssociationId $associationId 

