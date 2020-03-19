Write-Verbose "$PSScriptRoot\output deleted"
Remove-Item $PSScriptRoot\output\* -ea 0 -Force -Recurse
$null = mkdir $PSScriptRoot\output -ea 0
Set-Location $PSScriptRoot\output

Write-Host "Starting Run Region"
$regions = @('us-west-1', 'us-east-2')

foreach ($region in $regions) {
    Set-DefaultAWSRegion $region
    & '..\Run Sequence.ps1' -Region $region -CleanOutput $false
}
