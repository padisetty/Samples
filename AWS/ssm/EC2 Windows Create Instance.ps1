# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel
#     $obj - This is a global dictionary, used to pass output values
#            (e.g.) report the metrics back, or pass output values that will be input to subsequent functions

param ($Name = 'ssmwindows',
        $InstanceType = 't2.micro',
        $ImagePrefix='Windows_Server-2012-R2_RTM-English-64Bit-Base-20',
        #$ImagePrefix='Windows_Server-2016-English-Full-Base-20',
        $InstanceCount=2,
        $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
        [string] $SetupAction = ''  # SetupOnly or CleanupOnly
        )

$parallelName = "$Name$ParallelIndex"
. ..\ssmcommon.ps1 $Region

Write-Verbose "Windows Create Instance Name=$Name, InstanceType=$InstanceType, ImagePrefix=$ImagePrefix, Region=$Region"

. "..\EC2 Terminate Instance.ps1" $parallelName

if ($SetupAction -eq 'CleanupOnly') {
    return
} 

$securityGroup = @('test')
if (Get-EC2SecurityGroup | ? GroupName -eq 'corp') {
    $securityGroup += 'corp'
}

#Create Instance
Write-Verbose 'Creating EC2 Windows Instance.'
$instances = New-WinEC2Instance -Name $Name -InstanceType $InstanceType `
                        -ImagePrefix $ImagePrefix -SSMHeartBeat  -InstanceCount $InstanceCount `
                        -IamRoleName 'test' -SecurityGroupName $securityGroup -KeyPairName 'test'

$obj = @{}
$obj.'InstanceType' = $instances[0].Instance.InstanceType
$InstanceIds = $Obj.'InstanceIds' = $instances.InstanceId
$Obj.'ImageName' = (get-ec2image $instances[0].Instance.ImageId).Name
$obj.'PingTime' = $instances[0].Time.Ping.ToString()
$obj.'SSHTime' = $instances[0].Time.SSH.ToString()
$obj.'SSMHeartBeatSincePing' = $instances[0].Time.SSMHeartBeatSincePing.ToString()


return $obj