param ($Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'))
. "$PSScriptRoot\..\ssm\ssmcommon.ps1" $Region


function CFNCreateStack ([string]$StackName, [string]$TemplateBody, $obj = $null) {
    Write-verbose "Create Stack: StackName=$StackName, TemplateBody=$TemplateBody"

    $startTime = Get-Date

    $stackId = New-CFNStack -StackName $StackName -TemplateBody $TemplateBody
    Write-Verbose "CFN StackId=$stackId"

    $cmd = { $stack = Get-CFNStack -StackName $StackName; Write-Verbose "CFN Stack $StackName Status=$($stack.StackStatus)"; if ($stack.StackStatus -like '*_COMPLETE') {$stack} }
    $stack = Invoke-PSUtilWait -Cmd $cmd -Message 'CFN Stack' -RetrySeconds 120 -SleepTimeInMilliSeconds 2000

    if ($stack.StackStatus -ne 'CREATE_COMPLETE') {
        foreach($event in (Get-CFNStackEvents -StackName $StackName)) {
            if ($event.ResourceStatus -like '*FAILED*') {
                Write-Verbose "ResourceStatusReason=$($event.ResourceStatusReason), ResourceType=$($event.ResourceType), LogicalResourceId=$($event.LogicalResourceId), ResourceStatus=$($event.ResourceStatus)"
            }
        }
        Write-Error "Stack create failed. Status=$($stack.StackStatus), StackStatusReason=$($stack.StackStatusReason)"
    }

    if ($obj) {
        $obj.'StackCreateTime' = (Get-Date) - $startTime
    }
    return $stack
}


function CFNCreateStackWithChangeSet ([string]$StackName, [string]$TemplateBody, $obj = $null) {
    Write-verbose "Create StackWithChangeSet: StackName=$StackName, TemplateBody=$TemplateBody"

    $startTime = Get-Date

    $dummy = @"
Description: "Create SSM Parameter"
Resources:
  BasicParameter`:
    Type: "AWS::SSM::Parameter"
    Properties:
      Name: "$StackName"
      Type: "String"
      Value: "Dummy Value"
      Description: "SSM Parameter created via CloudFormation"
"@
    CFNCreateStack -StackName $StackName -TemplateBody $dummy

    Remove-CFNChangeSet -StackName $stackName -ChangeSetName $stackName -Force
    $changesetid = New-CFNChangeSet -StackName $StackName -TemplateBody $TemplateBody -ChangeSetName $StackName  -Capabilities CAPABILITY_IAM
    Write-Verbose "CFN ChangeSetId=$changesetid"
    Get-CFNChangeSet -StackName $stackName -ChangeSetName $stackName

    $cmd = { $changeset = Get-CFNChangeSet -StackName $StackName -ChangeSetName $StackName; Write-Verbose "CFN Stack $StackName Status=$($changeset.Status)"; if ($changeset.Status -like '*_COMPLETE' -or $changeset.Status -like 'FAILED') {$changeset} }
    $changeset = Invoke-PSUtilWait -Cmd $cmd -Message 'CFN Stack ChangeSet' -RetrySeconds 120 -SleepTimeInMilliSeconds 2000

    if ($changeset.Status -ne 'CREATE_COMPLETE') {
        Write-Error "ChangeSet create failed. Status=$($changeset.Status), StatusReason=$($changeset.StatusReason)"
    }

    Write-Verbose "Changes:"
    foreach ($change in $changeset.Changes.ResourceChange) {
        Write-Verbose "$($change.Action) $($Change.ResourceType) ($($change.LogicalResourceId))"
    }

    Start-CFNChangeSet -StackName $StackName -ChangeSetName $StackName 

    $cmd = { $stack = Get-CFNStack -StackName $StackName; Write-Verbose "CFN Stack $StackName Status=$($stack.StackStatus)"; if ($stack.StackStatus -like '*_COMPLETE') {$stack} }
    $stack = Invoke-PSUtilWait -Cmd $cmd -Message 'CFN Stack' -RetrySeconds 120 -SleepTimeInMilliSeconds 2000

    if ($stack.StackStatus -ne 'UPDATE_COMPLETE') {
        foreach($event in (Get-CFNStackEvents -StackName $StackName)) {
            if ($event.ResourceStatus -like '*FAILED*') {
                Write-Verbose "ResourceStatusReason=$($event.ResourceStatusReason), ResourceType=$($event.ResourceType), LogicalResourceId=$($event.LogicalResourceId), ResourceStatus=$($event.ResourceStatus)"
            }
        }
        Write-Error "Stack create failed. Status=$($stack.StackStatus), StackStatusReason=$($stack.StackStatusReason)"
    }



    if ($obj) {
        $obj.'StackCreateTime' = (Get-Date) - $startTime
    }

    return $stack
}



function CFNDeleteStack ([string]$StackName, $obj = $null)
{
    $startTime = Get-Date
    if (Get-CFNStack | ? StackName -eq $StackName) {
        Write-Verbose "Removing CFN Stack $StackName"
        Remove-CFNStack -StackName $StackName -Force

        $cmd = { 
                    $stack = Get-CFNStack | ? StackName -eq $StackName
                    Write-Verbose "CFN Stack $parallelName Status=$($stack.StackStatus)"
                    -not $stack
                }

        $null = Invoke-PSUtilWait -Cmd $cmd -Message "Remove Stack $StackName" -RetrySeconds 300 -SleepTimeInMilliSeconds 2000
    } else {
        Write-Verbose "Skipping Remove CFN Stack, as Stack with Name=$StackName not found"
    }
    if ($obj) {
        $obj.'StackDeleteTime' = (Get-Date) - $startTime
    }
}
