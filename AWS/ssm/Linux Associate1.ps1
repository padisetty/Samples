param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )

. $PSScriptRoot\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $instances = Get-WinEC2Instance $Name -DesiredState 'running'
    $InstanceIds = $instances.InstanceId
} else {
    $instances = Get-WinEC2Instance ($InstanceIds -join ',')
}

$DocumentName = 'AWS-RunShellScript'
$AssociationName = "$DocumentName-Associate-$Name"
Write-Verbose "Linux Associate1: InstanceIds=$($instances.InstanceId), DocumentName=$DocumentName, AssociationName=$AssociationName"
SSMDeleteAssociation -AssociationName $AssociationName

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

function generateExpected () {
    $expected = Get-Random -Maximum 1000
    Write-Verbose "Generated Expected Random Value=$expected"
    $null = Invoke-WinEC2Command $instances "echo $expected > /tmp/input"
    return $expected
}


function checkExpected ($expected) {
    foreach ($instance in $instances) {
        Write-Verbose ''
        $cmd = { 
            $output = Invoke-WinEC2Command $instance "cat /tmp/output" 4>$null
            Write-Verbose "Output=$output, Expected=$expected, InstanceId=$($instance.InstanceId)"
            if ($output -ne $expected) { $false } else { $true }
        }
        $null = Invoke-PSUtilWait -Cmd $cmd -Message "Apply Association Expected=$expected" -RetrySeconds 100 -SleepTimeInMilliSeconds 5000
    }
}

$expected = generateExpected

#Create Association
$associationId = (SSMAssociateTarget -AssociationName $AssociationName -DocumentName $DocumentName -Targets @{Key='instanceids';Values=$instances.InstanceId} -Parameters @{commands='cat /tmp/input > /tmp/output'}).AssociationId
Write-Verbose "#PSTEST# AssociationId=$associationId"
#SSMWaitForMapping -InstanceIds $instances.InstanceId -AssociationCount 1 -AssociationId $associationId

#return hashtable
@{AssociationId=$associationId} 
if ($SetupAction -eq 'SetupOnly') {
    return
} 

checkExpected $expected

#$expected = generateExpected
#SSMRefreshAssociation $instances.InstanceId $associationId
#    #SSMWaitForAssociation -InstanceId $instances.InstanceId -ExpectedAssociationCount 1 -MinS3OutputSize 0 -AssociationId $associationId
#checkExpected $expected

SSMDeleteAssociation -AssociationName $AssociationName