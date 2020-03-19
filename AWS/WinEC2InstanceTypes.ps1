trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

#$instancetypes = 'm3.medium', 'm3.large', 'm3.xlarge', 'm3.2xlarge', 'c3.large', 'c3.xlarge', 'c3.2xlarge', 'c3.4xlarge', 'c3.8xlarge', 'r3.large', 'r3.xlarge', 'r3.2xlarge', 'r3.4xlarge', 'r3.8xlarge', 'g2.2xlarge', 'i2.xlarge', 'i2.2xlarge', 'i2.4xlarge', 'i2.8xlarge', 'hs1.8xlarge', 't2.micro', 't2.small', 't2.medium'
$instancetypes = 'm3.medium', 'c3.large', 'r3.large', 'g2.2xlarge', 'i2.xlarge', 'hs1.8xlarge', 't2.medium'

$imagePrefixes = 'Windows_Server-2012-R2_RTM-English-64Bit-GP2-2014.06.11', 
                 'Windows_Server-2008-R2_SP1-English-64Bit-Base',
                 'Windows_Server-2012-R2_RTM-English-64Bit-Base',
                'Windows_Server-2012-RTM-English-64Bit-Base'

try
{
    Remove-WinEC2Instance *
}
catch
{}
foreach ($imagePrefix in $imagePrefixes)
{
    $instance = New-WinEC2Instance -NewPassword 'Secret.' -ImagePrefix $imagePrefix

    foreach ($instancetype in $instancetypes)
    {
        Write-Host "Changing to instancetype=$instancetype"
        Stop-WinEC2Instance $instance.InstanceId
        Edit-EC2InstanceAttribute $instance.InstanceId -InstanceType $instancetype
        Start-WinEC2Instance $instance.InstanceId $cred
    }

    Remove-WinEC2Instance $instance.InstanceId
}


# i-36a9d01d