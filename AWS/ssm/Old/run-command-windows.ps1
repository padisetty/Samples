param($ImageName = 'WINDOWS_2012R2_BASE', $Region = 'us-east-1', $S3Bucket='sivaiadbucket')

Write-Host "***********************************" -ForegroundColor Yellow
Write-Host "ImangeName=$ImageName" -ForegroundColor Yellow
Write-Host "***********************************" -ForegroundColor Yellow

Set-DefaultAWSRegion $Region
$VerbosePreference='Continue'
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
cd $PSScriptRoot
. .\ssmcommon.ps1
$index = '1'
if ($psISE -ne $null)
{
    #Role name is suffixed with the index corresponding to the ISE tab
    #Ensures to run multiple scripts concurrently without conflict.
    $index = $psISE.CurrentPowerShellTab.DisplayName.Split(' ')[1]
}
$instanceName = "ssm-demo-$index"






Write-Host "`nCreate Keypair winec2keypair if not present and save the in c:\keys" -ForegroundColor Yellow
SSMCreateKeypair





Write-Host "`nCreate Role winec2role if not present" -ForegroundColor Yellow
SSMCreateRole




Write-Host "`nCreate SecurityGroup winec2securitygroup if not present" -ForegroundColor Yellow
SSMCreateSecurityGroup 




Write-Host "`nCreate instance(s) and name it as $instanceName" -ForegroundColor Yellow
$instanceId = SSMCreateWindowsInstance -Tag $instanceName -InstanceCount 3 -ImageName $ImageName




Write-Host "`nAWS-RunPowerShellScript: Simple PowerShellScript" -ForegroundColor Yellow
$command = SSMRunCommand `
    -InstanceIds $instanceId `
    -Parameters @{
        commands=@(
         'ipconfig'
        )
     }  `
    -Outputs3BucketName $S3Bucket

return








Write-Host "`nAWS-InstallApplication: Install 7zip using InstallApplication" -ForegroundColor Yellow
$command = SSMRunCommand `
    -InstanceIds $instanceId `
    -DocumentName 'AWS-InstallApplication' `
    -Parameters @{
        source='http://downloads.sourceforge.net/project/sevenzip/7-Zip/15.12/7z1512-x64.msi'
     } 
SSMDumpOutput $command

$command = SSMRunCommand `
    -InstanceIds $instanceId `
    -Parameters @{
        commands='gwmi win32_product | select Name'
     }  `
    -Outputs3BucketName $S3Bucket
SSMDumpOutput $command









Write-Host "`nAWS-InstallPowerShellModule: install PSDemo PS module and execute Test1 function from that" -ForegroundColor Yellow
function PSUtilZipFolder(
    $SourceFolder, 
    $ZipFileName, 
    $IncludeBaseDirectory = $true)
{
    del $ZipFileName -ErrorAction 0
    Add-Type -Assembly System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder,
        $ZipFileName, [System.IO.Compression.CompressionLevel]::Optimal, 
        $IncludeBaseDirectory)
}
$dir = pwd
PSUtilZipFolder -SourceFolder "$dir\PSDemo" `
    -ZipFileName "$dir\PSDemo.zip" -IncludeBaseDirectory $false
write-S3Object -BucketName $S3Bucket -key 'public/PSDemo.zip' `
    -File $dir\PSDemo.zip -PublicReadOnly
del $dir\PSDemo.zip 
$command = SSMRunCommand `
    -InstanceIds $instanceId `
    -DocumentName 'AWS-InstallPowerShellModule' `
    -Parameters @{
        source="https://s3.amazonaws.com/$S3Bucket/public/PSDemo.zip"
        commands=@('Test1')
     }  `
    -Outputs3BucketName $S3Bucket
SSMDumpOutput $command
Remove-S3Object -BucketName $S3Bucket -Key 'public/PSDemo.zip' -Force








#Write-Host "`nAWS-RunPowerShellScript: Bootsrap Chocolatey and install node.js" -ForegroundColor Yellow
#$command = SSMRunCommand `
#    -InstanceIds $instanceId `
#    -Parameters @{
#        commands=@(
#        '$url = "https://chocolatey.org/install.ps1"',
#        'iex ((new-object net.webclient).DownloadString($url)) *> $null',
#        'choco install nodejs.install'
#        )
#     }  `
#    -Outputs3BucketName $S3Bucket










#Cleanup
Write-Host "`nTerminating instance" -ForegroundColor Yellow
#SSMRemoveInstance $instanceName

#SSMRemoveRole

#SSMRemoveKeypair

#SSMRemoveSecurityGroup 
