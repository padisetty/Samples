param ($Name)

echo $Name
$host.ui.RawUI.WindowTitle = $Name

if (! (Test-PSTestExecuting)) {
    . "$PSScriptRoot\Common Setup.ps1"
}

Write-Verbose 'Executing Run'


$InputParameters = @(
    @{Name=$Name;ImagePrefix='Windows Server 2012 R2'}
)


$tests = @(
    "$PSScriptRoot\Windows Create Instance.ps1"
    "$PSScriptRoot\Terminate Instance.ps1"
)
Invoke-PsTest -Test $tests -InputParameters $InputParameters  -Count 1 -StopOnError -LogNamePrefix 'Azure Windows'


gstat

Convert-PsTestToTableFormat    

