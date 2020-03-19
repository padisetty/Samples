Write-Verbose "Demo Cleanup"
$InstanceIds = $Name = $null
$host.ui.RawUI.WindowTitle = $Name

Write-Verbose "$PSScriptRoot\output deleted"
Remove-Item $PSScriptRoot\output\* -ea 0 -Force -Recurse
$null = md $PSScriptRoot\output -ea 0
cd $PSScriptRoot\output

. "..\Setup.ps1" 'us-east-1'
Write-Verbose 'Executing Demo Setup'

$tests = @(
    "$PSScriptRoot\Automation with Lambda.ps1"
    "$PSScriptRoot\Linux RC2 with Parameter Store.ps1"
    "$PSScriptRoot\Linux RC3 from Automation.ps1"
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-UpdateSSMAgent"
        Schedule = "cron(0 0 0 ? * SUN *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-RunPatchBaseline"
        Parameters = @{Operation='Scan'}
        Schedule = "cron(0 2 0 ? * SUN *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-GatherSoftwareInventory"
        Schedule = "cron(0 0/30 * 1/1 * ? *)"
    }
    "$PSScriptRoot\Maintenance Window.ps1"

    "$PSScriptRoot\EC2 Terminate Instance.ps1"
)
$commonParameters = @{
    Name="LinuxDemo"
    SetupAction='CleanupOnly'
    PsTestSuiteRepeat=1
}
Invoke-PsTest -Test $tests -CommonParameters $commonParameters -LogNamePrefix 'EC2 Linux'


$tests = @(
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-UpdateSSMAgent"
        Schedule = "cron(0 0 0 ? * SUN *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-RunPatchBaseline"
        Parameters = @{Operation='Scan'}
        Schedule = "cron(0 2 0 ? * SUN *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-GatherSoftwareInventory"
        Schedule = "cron(0 0/30 * 1/1 * ? *)"
    }
    "$PSScriptRoot\EC2 Terminate Instance.ps1"
)
$commonParameters = @{
    Name="WindowsDemo"
    SetupAction='CleanupOnly'
    ImagePrefix='Windows_Server-2016-English-Full-Base-20'
    PsTestSuiteRepeat=1
}
Invoke-PsTest -Test $tests -CommonParameters $commonParameters -LogNamePrefix 'EC2 Windows'

