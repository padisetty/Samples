#Name should be non zero, when run in parallel.
param ($Name)

Set-DefaultAWSRegion 'us-east-1'

echo $Name
$host.ui.RawUI.WindowTitle = $Name

. $PSScriptRoot\..\ssm\ssmcommon.ps1

if ($Name.Length -eq 0) {
    . "$PSScriptRoot\Setup.ps1"
}

Write-Verbose 'Executing Run'

$tests = @(
    "$PSScriptRoot\Create Instance.ps1"
    "$PSScriptRoot\Run Command.ps1"
    "$PSScriptRoot\Restart Instance.ps1"
    "$PSScriptRoot\Stop Start Instance.ps1"
    "$PSScriptRoot\Terminate Instance.ps1"
)




$InputParametersSets = @(
    @{
        Name=$Name
        AmiId='ami-14226b03'
    }
)
Invoke-PsTest -Test $tests -InputParameterSets $InputParametersSets  -Count 1 -LogNamePrefix 'Perf' -StopOnError


gstat

Convert-PsTestToTableFormat    


if ($Name.Length -eq 0) {
    & "$PSScriptRoot\Cleanup.ps1"
}