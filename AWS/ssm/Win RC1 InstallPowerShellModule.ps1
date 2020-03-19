param (
    $Name = (Get-PSUtilDefaultIfNull -value $Name -defaultValue 'ssmwindows'), 
    $InstanceIds = $InstanceIds,
    $Region = (Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'),
    [string] $SetupAction = ''  # SetupOnly or CleanupOnly
    )

if ($SetupAction -eq 'CleanupOnly') {
    return
} 
. $PSScriptRoot\ssmcommon.ps1 $Region

if ($InstanceIds.Count -eq 0) {
    Write-Verbose "InstanceIds is empty, retreiving instance with Name=$Name"
    $InstanceIds = (Get-WinEC2Instance $Name -DesiredState 'running').InstanceId
}
Write-Verbose "Windows RC1 InstallPowerShellModule: Name=$Name, InstanceId=$instanceIds"

$dir = $PSScriptRoot

Compress-Archive -Path "$dir\PSDemo\*" -DestinationPath "$dir\PSDemo.zip" -Force

$s3Bucket = Get-SSMS3Bucket
Write-Verbose "Bucket=$S3Bucket"
$s3ZipKey = "SSMOutput/$Name/PSDemo.zip"
$s3KeyPrefix = 'ssm/command'

Write-Verbose "Bucket=$S3Bucket, Key=$s3ZipKey"
write-S3Object -BucketName $S3Bucket -key $s3ZipKey -File $dir\PSDemo.zip -PublicReadOnly

del $dir\PSDemo.zip 

if ($Region -eq 'us-east-1') {
    $endpoint="s3"
} else {
    $endpoint="s3.$Region"
}
$startTime = Get-Date
$command = SSMRunCommand `
    -InstanceIds $InstanceIds `
    -DocumentName 'AWS-InstallPowerShellModule' `
    -SleepTimeInMilliSeconds 5000 `
    -Parameters @{
        source="https://$endpoint.amazonaws.com/$S3Bucket/$s3ZipKey"
        commands=@('ApplyConfiguration')
     } `
     -Outputs3BucketName $s3Bucket -Outputs3KeyPrefix $s3KeyPrefix

$obj = @{}
$obj.'CommandId' = $command
$obj.'RunCommandTime' = (Get-Date) - $startTime

Test-SSMOuput $command -ExpectedMinLength 0  -ExpectedMaxLength 10000

#$null = Remove-S3Object -BucketName $S3Bucket -Key $s3ZipKey -Force

if ($command.OutputS3BucketName -ne $s3Bucket) {
    throw "OutputS3BucketName did not match. Actual Bucket=$($command.OutputS3BucketName), Expected=$s3Bucket, CommandId=$($command.CommandId)"
}
if ($command.OutputS3KeyPrefix -ne $s3KeyPrefix) {
    throw "OutputS3KeyPrefix did not match. Actual OutputS3KeyPrefix=$($command.OutputS3KeyPrefix), Expected=$s3KeyPrefix, CommandId=$($command.CommandId)"
}

return $obj