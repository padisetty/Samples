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

Write-Verbose "SSM Parameter: Name=$Namme, ParallelIndex=$ParallelIndex, Count=$Count, Region=$Region, SetupAction=$SetupAction"

CFNDeleteStack $parallelName

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

#Create Instance
$cfnTemplate = @"
Description: "Create SSM Parameter"
Resources:
"@

for ($i=1; $i -le $Count; $i++) {
$cfnTemplate += @"

  BasicParameter$i`:
    Type: "AWS::SSM::Parameter"
    Properties:
      Name: "$parallelName-$i"
      Type: "String"
      Value: "$parallelName-$i's value"
      Description: "SSM Parameter created via CloudFormation"
      AllowedPattern: "^[a-zA-Z0-9' \\-]{1,100}$"
"@
}

$obj = @{}

$stack = CFNCreateStack -StackName $parallelName -TemplateBody $cfnTemplate -obj $obj
$obj.'StackId' = $stack.stackId

CFNDeleteStack -StackName $parallelName -obj $obj

return $obj