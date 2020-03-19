param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmlinux'), 
    $ParallelIndex,
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1')
    )

$parallelName = "$Name$ParallelIndex"
. $PSScriptRoot\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$parallelName"
    $InstanceIds = (Get-WinEC2Instance $parallelName -DesiredState 'running').InstanceId
}

Write-Verbose "EC2 Terminate: Name=$parallelName, InstanceIds=$instanceIds, ParallelIndex=$ParallelIndex"

function CFNDeleteStack ([string]$StackName)
{
    if (Get-CFNStack | ? StackName -eq $StackName) {
        Write-Verbose "Removing CFN Stack $StackName"
        Remove-CFNStack -StackName $StackName -Force

        $cmd = { 
                    $stack = Get-CFNStack | ? StackName -eq $StackName
                    Write-Verbose "CFN Stack $parallelName Status=$($stack.StackStatus)"
                    -not $stack
                }

        $null = Invoke-PSUtilWait -Cmd $cmd -Message "Remove Stack $StackName" -RetrySeconds 300 -SleepTimeInMilliSeconds 1000
    } else {
        Write-Verbose "Skipping Remove CFN Stack, as Stack with Name=$StackName not found"
    }
}

CFNDeleteStack $parallelName

#Terminate
foreach ($instanceId in $InstanceIds) {
    Remove-WinEC2Instance $instanceId -NoWait
}

Remove-WinEC2Instance $parallelName -NoWait