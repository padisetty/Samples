#Set-DefaultAWSRegion 'us-east-1'
$VerbosePreference='Continue'
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'

ipmo PSUtil -Global -Force

function GetSupportedInstanceTypesAndRegion ([Hashtable]$BuildRegions, [Switch]$IgnoreError)
{
    $instanceTypes = @('t2.nano', 't2.micro', 't2.small', 't2.medium', 't2.large'
      'm3.medium', 'm3.large', 'm3.2xlarge'
      'c3.large', 'c3.xlarge', 'c3.2xlarge', 'c3.4xlarge', 'c3.8xlarge'
      'r3.large', 'r3.xlarge', 'r3.2xlarge', 'r3.4xlarge', 'r3.8xlarge'
      'g2.2xlarge'
      'm4.large', 'm4.xlarge', 'm4.2xlarge', 'm4.4xlarge', 'm4.10xlarge'
      'c4.large', 'c4.xlarge', 'c4.2xlarge', 'c4.4xlarge', 'c4.8xlarge'
      'i2.xlarge', 'i2.2xlarge', 'i2.4xlarge', 'i2.8xlarge'
      'd2.xlarge', 'd2.2xlarge', 'd2.4xlarge', 'd2.8xlarge')


    $result = @{}
    foreach ($imageName in $BuildRegions.Keys) {
        $result.$imageName = @{}
        foreach ($region in $BuildRegions.$imageName) {
            Write-Verbose ''
            Write-Verbose "Image=$imageName, Region=$region"
            Set-DefaultAWSRegion $region
            $result.$imageName.$region = @()

            $image = Get-EC2ImageByName $ImageName | select -First 1
            Write-Verbose $image.Name
            $first = $true
            foreach ($instanceType in $instanceTypes) {
                Write-Verbose "$instanceType ($region)"
                $errorFound = $false
                foreach ($availabilityZone in (Get-EC2AvailabilityZone | sort -Descending -Property 'ZoneName')) {
                    try {
                        $instance = (New-EC2Instance -ImageId $image.ImageId -InstanceType $instanceType -AvailabilityZone $availabilityZone.ZoneName).Instances[0]
                        Write-Verbose "    $($availabilityZone.ZoneName) InstanceType=$instanceType Success"
                        if ($IgnoreError) { break }
                    } catch {
                        $errorFound = $true
                        Write-Verbose "    $($availabilityZone.ZoneName) InstanceType=$instanceType Fail"
                        break
                    } finally {
                        if ($instance) {
                            for ($i=0; $i -lt 5; $i++) {
                                try {
                                    $null = Stop-EC2Instance $instance.InstanceId -Terminate -Force
                                    break
                                } catch {
                                    Write-Verbose "  $($_.Exception.Message)"
                                    Sleep -Seconds 2
                                }
                            } 
                            $instance = $null
                        }
                    } 
                }
                if ($errorFound) {
                    Write-Verbose "    NOT supported $instanceType ($region)"
                } else {
                    Write-Verbose "    SUPPORTED $instanceType ($region)"
                    $first = $false
                    $result.$imageName.$region += $instanceType
                }
            }
        }
    }
    return $result
}

function GetSupportedInstanceTypesByImage () {
    $imageRegions = @{
                        'Windows_Server-*SQL*Enterprise*' = 'us-east-1'
                        'Windows_Server-2008-SP2-English-32Bit-SQL_2008_SP4_Web-*' = 'us-east-1'
                        'WINDOWS_2012R2_BASE'= 'us-east-1'
                        'WINDOWS_2012R2_SQL_SERVER_WEB_2014' = 'us-east-1'
                        'WINDOWS_2012R2_SQL_SERVER_STANDARD_2014' = 'us-east-1'
                     } 
    $result = GetSupportedInstanceTypesAndRegion $imageRegions -IgnoreError
    foreach ($image in $imageRegions.Keys) {
        $result.$image = $result.$image.'us-east-1'
    }
    return $result
}

function GetSupportedInstanceTypesByRegion () {
    $imageRegions = @{  'WINDOWS_2012R2_BASE'= (Get-AWSRegion).Region
                     } 
    $result = GetSupportedInstanceTypesAndRegion $imageRegions
    return $result.'WINDOWS_2012R2_BASE'
}

Convertto-PS GetSupportedInstanceTypesByRegion > c:\temp\x.ps1
Convertto-PS GetSupportedInstanceTypesByRegion >> c:\temp\x.ps1
