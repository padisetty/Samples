Write-Verbose "Demo Setup"
$InstanceIds = $Name = $null
$host.ui.RawUI.WindowTitle = $Name

Write-Verbose "$PSScriptRoot\output deleted"
Remove-Item $PSScriptRoot\output\* -ea 0 -Force -Recurse
$null = md $PSScriptRoot\output -ea 0
cd $PSScriptRoot\output

. "..\Setup.ps1" 'us-east-1'

Write-Verbose 'Executing Demo Setup'




$tests = @(
    "..\EC2 Linux Create Instance.ps1"
    "..\Automation with Lambda.ps1"
    "..\Linux RC2 with Parameter Store.ps1"
    "..\Linux RC3 from Automation.ps1"
    "..\Maintenance Window.ps1"

    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-RunPatchBaseline"
        Parameters = @{Operation='Install'}
        Schedule = "cron(0 2 0 ? * SUN *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-GatherSoftwareInventory"
        Schedule = "cron(0 0/30 * 1/1 * ? *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-UpdateSSMAgent"
        Schedule = "cron(0 0 1 * * ?)" # Every day at 1am
    }
)
$commonParameters = @{
    Name='LinuxDemo'
    SetupAction='SetupOnly'
    ImagePrefix='amzn-ami-hvm-201*-x86_64-gp2'
    InstanceCount=5

    PsTestSuiteRepeat=1

    PsTestSuiteMaxFail=10 # max failures allowed
    PsTestSuiteMaxConsecutiveFailPerTest=3 # 1..PsTestSuiteRepeat, multiple failures in the same test is counted as 1 
}
Invoke-PsTest -Test $tests -CommonParameters $commonParameters -LogNamePrefix 'EC2 Linux Demo'

$tests = @(
    "..\EC2 Windows Create Instance.ps1"
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-GatherSoftwareInventory"
        Schedule = "cron(0 0/30 * 1/1 * ? *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-RunPatchBaseline"
        Parameters = @{Operation='Install'}
        Schedule = "cron(0 2 0 ? * SUN *)"
    }
    @{
        PsTest = "..\Associate.ps1"
        DocumentName = "AWS-UpdateSSMAgent"
        Schedule = "cron(0 0 1 * * ?)" # Every day at 1am
    }
)
$commonParameters = @{
    Name='WindowsDemo'
    SetupAction='SetupOnly'
    #ImagePrefix='Windows_Server-2016-English-Full-Base-20'
    ImagePrefix='Windows_Server-2012-R2_RTM-English-64Bit-Base-20'
    InstanceCount=2

    PsTestSuiteRepeat=1

    PsTestSuiteMaxFail=10 # max failures allowed
    PsTestSuiteMaxConsecutiveFailPerTest=3 # 1..PsTestSuiteRepeat, multiple failures in the same test is counted as 1 
}
Invoke-PsTest -Test $tests -CommonParameters $commonParameters -LogNamePrefix 'EC2 Windows Demo'
