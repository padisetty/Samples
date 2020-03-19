param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'demo'), 
    $ParallelIndex,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1')
    )
$parallelName = "$Name$ParallelIndex"

. $PSScriptRoot\..\ssmcommon.ps1 $Region

Write-Verbose "Region=$Region, SetupAction=$SetupAction"

$parameters = @{
    Name = $parallelName
}
$files = Get-ChildItem -Path "$PSScriptRoot\SC*.yaml"

$obj = @{}

foreach ($file in $files) {
    Write-Verbose ''
    Write-Verbose "-------------------------------------------------------------------------------"
    Write-Verbose "File: $($file.BaseName)"
    Write-Verbose "-------------------------------------------------------------------------------"
    $doc = Get-Content $file -Raw

    $DocumentName = "$($file.BaseName.Replace(' ','_')).$parallelName"

    SSMDeleteDocument $DocumentName

    SSMCreateDocument -DocumentName $DocumentName -DocumentContent $doc -DocumentType 'Automation' -DocumentFormat 'YAML'

    $startTime = Get-Date

    SSMExecuteAutomation -DocumentName  $DocumentName -Parameters $parameters -SleepTimeInMilliSeconds 5000 -Timeout 1200

    $obj."$($file.BaseName) Time" = (Get-Date) - $startTime
    SSMDeleteDocument $DocumentName
}

$obj


