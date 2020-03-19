param (
    $Name=$null,
    $Region='us-east-1',
    $CleanOutput=$true
)

cls
. "$PSScriptRoot\cfncommon.ps1" $Region
$SetupAction=''
#$SetupAction='CleanupOnly'
#$SetupAction='SetupOnly'

$PsTestSuiteRepeat=10 # Number of times the entire suite to repeat

$PsTestMaxFail=10 # max failures allowed. It counts every single failure, no coalesing.
$PsTestSuiteMaxConsecutiveFailPerTest=4 # 1..PsTestSuiteRepeat, multiple failures in the same test is counted as 1 

#For each test, within the loop 1..PsTestRepeat
$PsTestRepeatMaxFail=5 # per test
$PsTestRepeatMaxConsecutiveFail=5 # consicutive failures within 1..PsTestRepeat


if ($CleanOutput) {
    Write-Verbose "$PSScriptRoot\output deleted"
    Remove-Item $PSScriptRoot\output\* -ea 0 -Force -Recurse
    $null = md $PSScriptRoot\output -ea 0
    cd $PSScriptRoot\output
}

$tests = @(
#    @{
#        PsTest = "..\CFN1 Simple EC2 Instance.ps1"
#    }
    @{
        PsTest = "..\SSM parameter.ps1"
    }
)


$commonParameters = @{
    Name="$($Name)cfn"
    Region=$Region
    
    SetupAction=$SetupAction

    #PsTestOnFail='..\OnFailure.ps1'
    PsTestSuiteRepeat=$PsTestSuiteRepeat # Number of times the entire suite to repeat

    PsTestMaxFail=$PsTestMaxFail # max failures allowed
    PsTestSuiteMaxConsecutiveFailPerTest=$PsTestSuiteMaxConsecutiveFailPerTest # 1..PsTestSuiteRepeat, multiple failures in the same test is counted as 1 

    PsTestRepeatMaxFail=$PsTestRepeatMaxFail # per test
    PsTestRepeatMaxConsecutiveFail=$PsTestRepeatMaxConsecutiveFail # consicutive failures within 1..PsTestRepeat
}
Invoke-PsTest -Test $tests -LogNamePrefix "$Region.cfn" -CommonParameters $commonParameters

