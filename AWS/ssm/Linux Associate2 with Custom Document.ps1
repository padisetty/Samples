param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $ParallelIndex,
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


function getdocument ($Message) {
    $doc = @"
{
    "schemaVersion": "2.0",
    "description": "Example instance configuration tasks for 2.0",
    "parameters":{
        "hello":{
            "type":"String",
            "description":"(Optional) List of association ids. If empty, all associations bound to the specified target are applied.",
            "displayType":"textarea",
            "default": "default"
        }
    },
    "mainSteps": [
        {
            "action": "aws:runShellScript",
            "name": "run",
            "inputs": {
                "runCommand": ["echo Doc1.v$Message - {{ hello }}"]
            }
        }
    ]
}
"@

    return $doc
}

#Delete the Document and recreate
$DocumentName = "AssociateRunShellScript.$ParallelIndex"
Write-Verbose "Linux Associate 1: InstanceIds=$($instances.InstanceId)"
SSMDeleteDocument $DocumentName
SSMDeleteAssociation -DocumentName $DocumentName

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

#SSMWaitForAssociation -InstanceId $instances.InstanceId -ExpectedAssociationCount 0 -MinS3OutputSize 0 -DocumentName $DocumentName
#Create Document
SSMCreateDocument $DocumentName (getdocument '1')

#Create Association for Document v1
if ((Get-Random) % 2 -eq 0) {
    Write-Verbose 'Associate with Tag'
    $query = @{Key='tag:Name';Values=$Name}
} else {
    Write-Verbose 'Associate with InstanceID'
    $query = @{Key='instanceids';Values=$instances.InstanceId}
}

$associationId = (SSMAssociateTarget -DocumentName $DocumentName -Targets $query  -Parameters @{hello=@('one')}).Associationid
Write-Verbose "#PSTEST# AssociationId=$associationId"

$startTime = Get-Date
SSMWaitForAssociation -InstanceId $instances.InstanceId -ExpectedAssociationCount 1 -MinS3OutputSize 13 -ContainsString 'Doc1.v1 - one' -AssociationId $associationId

@{
    AssociationId=$associationId
    Query=$query
}

<#
for ($i=1; $i -le 0; $i++) {
    #Sleep -Seconds 5
    Write-Verbose ''
    Write-Verbose "Iteration=$i"
    #SSMReStartAgent -Instances $instances
    $cmd = {
        SSMRefreshAssociation $instances.InstanceId -AssociationIds $associationId
        SSMWaitForAssociation -InstanceId $instances.InstanceId -ExpectedAssociationCount 1 -MinS3OutputSize 13 -ContainsString 'Doc1.v1 - one' -AssociationId $associationId
    }
    try {
        Invoke-PSUtilRetryOnError -ScriptBlock $cmd -RetryCount 1
    } catch {
        $sb = SSMGetAssociationInformation -AssociationId $associationId
        Write-Verbose ''
        Write-Verbose $sb.ToString()
        throw
    }

}

#Update the Document to v2
$doc1v2 = getdocument '2'
$null = Update-SSMDocument -Content $doc1v2 -Name $DocumentName -DocumentVersion '$LATEST'
$null = Update-SSMDocumentDefaultVersion -Name $DocumentName -DocumentVersion '2'
$a = Get-SSMDocument -Name $DocumentName
if ($a.Content -ne $doc1v2) {
    throw "Document content did not match after update. Expected:`n$doc1v2`nRetrieved:`n$($a.Content)"
}
Write-Verbose "$DocumentName updated to v2"

#delete any previous data from S3
Sleep -Seconds 15
SSMAssociateDeleteS3 -AssociationId $associationId


#Wait for Association to converge after Document update
for ($i=1; $i -le 1; $i++) {
    #Sleep -Seconds 5
    Write-Verbose ''
    Write-Verbose "Iteration=$i"
    #SSMReStartAgent -Instances $instances

    SSMRefreshAssociation $instances.InstanceId
    SSMWaitForAssociation -InstanceId $instances.InstanceId -ExpectedAssociationCount 1 -MinS3OutputSize 13 -ContainsString 'Doc1.v2 - one' -AssociationId $associationId
}
#>

Remove-SSMAssociation -AssociationId $associationId -Force

SSMDeleteDocument $DocumentName
