# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel


param ($Name = 'cfn', 
        $ParallelIndex,
        $Count=2,
        $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
        [string] $SetupAction = ''  # SetupOnly or CleanupOnly
)

$parallelName = "$Name$ParallelIndex"
. $PSScriptRoot\cfncommon.ps1 $Region

Write-Verbose "SAM: Name=$Namme, ParallelIndex=$ParallelIndex, Count=$Count, Region=$Region, SetupAction=$SetupAction"
CFNDeleteStack $parallelName

$bucket = Get-SSMS3Bucket
$keyprefix = "cfn/SAM/$parallelName/CFNTemplate.cfn"
Write-Verbose "Bucket=$bucket, Key=$keyprefix"

$null = Get-S3Object -BucketName $bucket -KeyPrefix $keyprefix | Remove-S3Object -Force

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

$cfnTemplateNested = @"
Description: "Create SSM Parameter"
Resources:
  BasicParameter`:
    Type: "AWS::SSM::Parameter"
    Properties:
      Name: "$parallelName-Nested"
      Type: "String"
      Value: "Nested Value"
      Description: "SSM Parameter created via CloudFormation"
"@

$codeFile = "$($Env:TEMP)\lambda$parallelName.cfn"
$cfnTemplateNested | Out-File -Encoding ascii $codeFile

Write-S3Object -BucketName $bucket -Key $keyprefix -File $codeFile

$cfnTemplate = @"
Description: "Nested CFN Stack Demo"
Resources:
  NestedStack:
    Type: "AWS::CloudFormation::Stack"
    Properties:
      TemplateURL: https://s3.amazonaws.com/$bucket/$keyprefix
"@

$obj = @{}

$stack = CFNCreateStack -StackName $parallelName -TemplateBody $cfnTemplate -obj $obj
$obj.'StackId' = $stack.stackId

CFNDeleteStack -StackName $parallelName -obj $obj

return $obj