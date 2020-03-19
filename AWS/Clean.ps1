param (
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1')
    )

Set-DefaultAWSRegion $Region

Write-Verbose "Clean $Region"

trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'

function GetRegion ([String]$bucketName) {
    $location = Get-S3BucketLocation -BucketName $bucketName
    if ($location.Value.Length -eq 0) {
        $region = 'us-east-1'
    } else {
        $region = $location.Value
    }
    return $region
}

function CleanS3 ([String]$region, [String]$bucketName, [String]$keyPrefix) {
    Write-Verbose ''
    Write-Verbose "S3 Cleaning bucket=$bucketName, KeyPrefix=$keyPrefix, Region=$region"

    while ($true) {
        $keys = (Get-S3Object -BucketName $bucketName -Key $keyPrefix -Region $region | select -First 100).Key
        if ($keys.Count -gt 0) {
            Write-Verbose "$($keys[0]) ..."
            Write-Verbose "Removing $($keys.Count) keys from region=$region with prefix=$bucketName/$keyPrefix"
            $null = Remove-S3Object -BucketName $bucketName -KeyCollection $keys -Force -Region $region
        } else {
            break
        }
    }
}

function CleanEC2Network ([String]$region) {
    Write-Verbose ''
    Write-Verbose "Network Cleaning Region=$region"

    $interfaces = Get-EC2NetworkInterface | ? { $_.Status -eq 'available' }
    foreach ($interface in $interfaces) {
        try {
            Write-Verbose "  PrivateIp=$($interface.PrivateIpAddress), VpcId=$($interface.VpcId), Status=$($interface.Status)"
            Remove-EC2NetworkInterface -NetworkInterfaceId $interface.NetworkInterfaceId -Force
        } catch {
            Write-Verbose "    $($_.Exception.Message)"
        }
    }
}

function CleanEC2Instance ([String]$region) {
    Write-Verbose ''
    Write-Verbose "EC2 Instance Cleaning Region=$region"

    $instances = (Get-EC2Instance -Filter @{Name = 'instance-state-name'; Value = 'running'} -Region $region).Instances
    foreach ($instance in $instances) {
        $found = $false
        $sb = New-Object System.Text.StringBuilder
        foreach ($tag in $instance.Tags) {
            if ($sb.Length -gt 0) {
                $null = $sb.Append(', ')
            }
            $null = $sb.Append("$($tag.Key)=$($tag.Value)")
            if ($tag.Key -eq 'Name' -and ($tag.Value -like '*dev*' -or $tag.Value -like '*save*')) {
                Write-Verbose "Skipping Instance=$($instance.InstanceId), Name=$($tag.Value)"
                $found = $true
                break
            }
        }
        if (! $found) {
            Write-Verbose "Terminating Region=$region, Instance=$($instance.InstanceId) $sb"
               
            $null = Remove-EC2Instance -Instance $instance.InstanceId -Force -Region $region
        }
    }
}

$bucket = Get-SSMS3Bucket
CleanEC2Instance $region
CleanS3 $region $bucket 'TestResults'
CleanS3 $region $bucket 'SSMOutput'
CleanS3 $region $bucket 'associate'
CleanS3 $region $bucket 'ssm'
#CleanEC2Network $region


Get-SSMActivation | % { Remove-SSMActivation -ActivationId $_.ActivationId -Force }

Get-SSMInstanceInformation | ? InstanceId -like 'mi-*' | % { Unregister-SSMManagedInstance -InstanceId $_.InstanceId }

Get-EC2Image -Owner 'self' | Unregister-EC2Image
Get-EC2Snapshot -OwnerId 'self' | Remove-EC2Snapshot -Force

Get-SSMDocumentList -DocumentFilterList @{key='Owner';Value='self'} | % { SSMDeleteDocument $_.Name }

Get-SSMAssociationList | % { Remove-SSMAssociation -AssociationId $_.AssociationId -Force }
Get-SSMMaintenanceWindowList | % { Remove-SSMMaintenanceWindow -WindowId $_.WindowId -Force }