param (
    $Name=$null,
    $Region='us-east-1',
    [boolean]$EC2Linux = $true,
    [boolean]$EC2Windows = $false,
    [boolean]$AzureWindows = $false,
    [boolean]$AzureLinux = $false,
    [boolean]$CFN = $false,
    [boolean]$CleanOutput = $true
)

$SetupAction=''
#$SetupAction='CleanupOnly'
#$SetupAction='SetupOnly'

$PsTestSuiteRepeat=1 # Number of times the entire suite to repeat

$PsTestMaxFail=10 # max failures allowed. It counts every single failure, no coalesing.
$PsTestSuiteMaxConsecutiveFailPerTest=4 # 1..PsTestSuiteRepeat, multiple failures in the same test is counted as 1 

#For each test, within the loop 1..PsTestRepeat
$PsTestRepeatMaxFail=5 # per test
$PsTestRepeatMaxConsecutiveFail=5 # consicutive failures within 1..PsTestRepeat

$InstanceIds = $Name = $null
Write-Host "Run Sequence - Name=$Name, Region=$Region, EC2Linux=$EC2Linux, EC2Windows=$EC2Windows, AzureWindows=$AzureWindows, AzureLinux=$AzureLinux"
$host.ui.RawUI.WindowTitle = $Name

Set-DefaultAWSRegion $Region
#$global:storedAWSRegion = $Region

Import-Module psutil,winec2,pstest -Global -Force -Verbose:$false

if ($CleanOutput) {
    Write-Verbose "$PSScriptRoot\output deleted"
    Remove-Item $PSScriptRoot\output\* -ea 0 -Force -Recurse
    $null = md $PSScriptRoot\output -ea 0
    cd $PSScriptRoot\output
}

. "$PSScriptRoot\Setup.ps1" $Region

Write-Verbose 'Executing Run'
#$null = Get-SSMAssociationList | % { Remove-SSMAssociation -AssociationId $_.AssociationId -Force }

#$bucket = Get-SSMS3Bucket
#$null = Get-S3Object -BucketName $bucket -Key '/ssm' | Remove-S3Object -Force
#$null = Get-S3Object -BucketName $bucket -Key '/SSMOutput' | Remove-S3Object -Force

if ($EC2Linux) {
    $tests = @(
       @{
            PsTest = "..\EC2 Linux Create Instance.ps1"
            ImagePrefix='amzn-ami-hvm-201*-x86_64-gp2'
            PsTestOutputKeys = @('InstanceIds', 'ImageName')
            InstanceCount = 3
            FailBehavior = 'SkipTests' # because if instances are not created, it does not make sense to run remaining tests
        }
        
        @{
            PsTest = "..\Send Command.ps1"
            DocumentName = "AWS-RunShellScript"
            PsTestRepeat = 1
            PsTestParallelCount = 5
        }

        @{
            PsTest = "..\Send Command.ps1"
            DocumentName = "AWS-UpdateSSMAgent"
            Parameters = @{}
        }
        
        @{
            PsTest = "..\Associate.ps1"
            DocumentName = "AWS-GatherSoftwareInventory"
            Schedule = "cron(0 0/30 * 1/1 * ? *)"
            PsTestParallelCount = 1
            PsTestRepeat = 1
        }
        @{
            PsTest = "..\Associate.ps1"
            DocumentName = "AWS-RunPatchBaseline"
            Parameters = @{Operation='Scan'}
            Schedule = "cron(0 2 0 ? * SUN *)"
        }

        @{
            PsTest = "..\Linux Associate1.ps1"
            PsTestParallelCount = 1
            PsTestRepeat = 1
        }
        @{
            PsTest = "..\Linux Associate2 with Custom Document.ps1"
            PsTestParallelCount = 1
            PsTestRepeat = 1
        }

        "..\Inventory with PutInventory and Config.ps1"

        @{
            PsTest = "..\Automation with Lambda.ps1"
            PsTestParallelCount = 5
            PsTestRepeat = 1
        }
        @{
            PsTest = "..\Linux RC1 Notification.ps1"
            PsTestParallelCount = 5
            PsTestRepeat = 1
        }
        @{
            PsTest = "..\Linux RC2 with Parameter Store.ps1"
            PsTestParallelCount = 5
            PsTestRepeat = 1
        }
   
        @{
            PsTest = "..\Linux RC3 from Automation.ps1"
            PsTestParallelCount = 5
            PsTestRepeat = 1
        }

        @{
            PsTest = "..\Maintenance Window.ps1"
            PsTestParallelCount = 5
            PsTestRepeat = 1
        }


        "..\EC2 Terminate Instance.ps1"
    )





    $tests = @(
        @{
            PsTest = "..\Automation with Lambda.ps1"
            PsTestParallelCount = 5
            PsTestRepeat = 1
        }
    )






    $commonParameters = @{
        Name="$($Name)ssmlinux"
        Region=$Region
    
        SetupAction=$SetupAction

        PsTestOnFail='..\OnFailure.ps1'
        PsTestSuiteRepeat=$PsTestSuiteRepeat # Number of times the entire suite to repeat

        PsTestMaxFail=$PsTestMaxFail # max failures allowed
        PsTestSuiteMaxConsecutiveFailPerTest=$PsTestSuiteMaxConsecutiveFailPerTest # 1..PsTestSuiteRepeat, multiple failures in the same test is counted as 1 

        PsTestRepeatMaxFail=$PsTestRepeatMaxFail # per test
        PsTestRepeatMaxConsecutiveFail=$PsTestRepeatMaxConsecutiveFail # consicutive failures within 1..PsTestRepeat
    }
    Invoke-PsTest -Test $tests -LogNamePrefix "$Region.Linux" -CommonParameters $commonParameters


    if ($CFN) {
        $tests = @(
            "..\EC2 Linux Create Instance CFN1.ps1"
            "..\Automation 1 Lambda.ps1"
            "..\Inventory1.ps1"
            "..\Linux RC1 RunShellScript.ps1"
            "..\Linux RC2 Notification.ps1"
            "..\Linux RC3 Stress.ps1"
            "..\Linux RC4 Param.ps1"
            "..\Linux RC5 Automation.ps1"
            "..\EC2 Terminate Instance.ps1"
        )
        Invoke-PsTest -Test $tests -Parameters $Parameters  -Count 1 -StopOnError -LogNamePrefix 'EC2 Linux CFN1'



        $tests = @(
            "..\EC2 Linux Create Instance CFN2.ps1"
            "..\Automation 1 Lambda.ps1"
            "..\Inventory1.ps1"
            "..\Linux RC1 RunShellScript.ps1"
            "..\Linux RC2 Notification.ps1"
            "..\Linux RC3 Stress.ps1"
            "..\Linux RC4 Param.ps1"
            "..\Linux RC5 Automation.ps1"
            "..\EC2 Terminate Instance.ps1"
        )
        Invoke-PsTest -Test $tests -Parameters $Parameters  -Count 1 -StopOnError -LogNamePrefix 'EC2 Linux CFN2'
    }
}

if ($EC2Windows) {
    $tests = @(
        @{
            PsTest = "..\EC2 Windows Create Instance.ps1"
            #ImagePrefix='Windows_Server-2016-English-Full-Base-20'
            ImagePrefix='Windows_Server-2012-R2_RTM-English-64Bit-Base-20'
        }
        @{
            PsTest = "..\Send Command.ps1"
            DocumentName = "AWS-RunPowerShellScript"
            Parameters = @{commands=@('ipconfig')}
            PsTestRepeat = 1
            PsTestParallelCount = 5
        }

        @{
            PsTest = "..\Send Command.ps1"
            DocumentName = "AWS-UpdateSSMAgent"
            Parameters = @{}
        }
        
        @{
            PsTest = "..\Associate.ps1"
            DocumentName = "AWS-GatherSoftwareInventory"
            Schedule = "cron(0 0/30 * 1/1 * ? *)"
            PsTestParallelCount = 1
            PsTestRepeat = 1
        }
        @{
            PsTest = "..\Associate.ps1"
            DocumentName = "AWS-RunPatchBaseline"
            Parameters = @{Operation='Scan'}
            Schedule = "cron(0 2 0 ? * SUN *)"
        }
        "..\Win RC1 InstallPowerShellModule.ps1"

        "..\Win RC2 InstallApplication.ps1"

        "..\EC2 Terminate Instance.ps1"
    )


    $commonParameters = @{
        Name="$($Name)ssmwindows"
        Region=$Region
        SetupAction=$SetupAction

        PsTestOnFail='..\OnFailure.ps1'
        PsTestSuiteRepeat=$PsTestSuiteRepeat # Number of times the entire suite to repeat

        PsTestMaxFail=$PsTestMaxFail # max failures allowed
        PsTestSuiteMaxConsecutiveFailPerTest=$PsTestSuiteMaxConsecutiveFailPerTest # 1..PsTestSuiteRepeat, multiple failures in the same test is counted as 1 

        PsTestRepeatMaxFail=$PsTestRepeatMaxFail # per test
        PsTestRepeatMaxConsecutiveFail=$PsTestRepeatMaxConsecutiveFail # consicutive failures within 1..PsTestRepeat
    }
    Invoke-PsTest -Test $tests -LogNamePrefix "$Region.Windows" -CommonParameters $commonParameters
}


if ($AzureWindows) {
    $tests = @(
        "..\Azure Windows Create Instance.ps1"
        "..\Win RC1 RunPowerShellScript.ps1"
        "..\Azure Terminate Instance.ps1"
    )
    $Parameters = @{
        Name='mc-'
        ImagePrefix='Windows Server 2012 R2'
    }
    Invoke-PsTest -Test $tests -Parameters $Parameters  -Count 1 -StopOnError -LogNamePrefix 'Azure Windows'
}


if ($AzureLinux) {
    $tests = @(
        "..\Azure Linux Create Instance.ps1"
        "..\Linux RC1 RunShellScript.ps1"
        "..\Azure Terminate Instance.ps1"
    )
    $Parameters = @{
        Name='mc-'
        ImagePrefix='Ubuntu Server 14'
    }
    Invoke-PsTest -Test $tests -Parameters $Parameters  -Count 1 -StopOnError -LogNamePrefix 'Azure Linux'
}


#Convert-PsTestToTableFormat    


if (! (Test-PSTestExecuting)) {
 #   & "..\Cleanup.ps1"
}