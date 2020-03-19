# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel
#     $obj - This is a global dictionary, used to pass output values
#            (e.g.) report the metrics back, or pass output values that will be input to subsequent functions

param ( $Name = '',
        $InstanceType = 't2.micro',
        $ImagePrefix='Windows_Server-2012-R2_RTM-English-64Bit-Base-20',
        $AmiId=$null,

        $IamRoleName='test',
        $SecurityGroupName='test',
        $KeyPairName='test',

        $Timeout=450,
        $Placement_AvailabilityZone=$null,
        $AdditionalInfo=$null)

Write-Verbose 'Executing Create Instance.'

. "$PSScriptRoot\Common Setup.ps1"

$Name = "perf$Name"

Remove-WinEC2Instance $Name -NoWait

$global:instance = New-WinEC2Instance -Name $Name -InstanceType $InstanceType `
                        -ImagePrefix $ImagePrefix -AmiId $AmiId `
                        -IamRoleName $IamRoleName -SecurityGroupName $SecurityGroupName -KeyPairName $KeyPairName `
                        -Timeout $Timeout  -Placement_AvailabilityZone $Placement_AvailabilityZone -AdditionalInfo $AdditionalInfo -DontCleanUp:$true

#$global:instance = Get-WinEC2Instance $Name

$Obj.'InstanceId' = $instance.InstanceId
$obj.'PublicIpAddress' = $instance.PublicIpAddress
$Obj.'KeyPairName' = $KeyPairName
$Obj.'ImageName' = (get-ec2image $instance.Instance.ImageId).Name
$obj.RunningTime = $instance.Time.Running
$obj.PingTime = $instance.Time.Ping
$obj.PasswordTime = $instance.Time.Password
$obj.RemoteTime = $instance.Time.Remote
$obj.AZ = $instance.Instance.Placement.AvailabilityZone
$obj.EbsOptimized = $instance.Instance.EbsOptimized
$obj.'InstanceType' = $Instance.Instance.InstanceType