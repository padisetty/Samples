param($ImageName = 'amzn-ami-hvm-*gp2', $Region = 'us-east-1', $S3Bucket='sivaiadbucket')

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
$instanceId = SSMCreateLinuxInstance -Tag $instanceName -ImageName $ImageName -InstanceCount 3





$script = @'
    ifconfig
    #cd /tmp
    echo working dir=`pwd`
'@.Replace("`r",'')

Write-Host "`nAWS-RunShellScript: Excute shell script" -ForegroundColor Yellow
$command = SSMRunCommand `
    -InstanceIds $instanceId `
    -DocumentName 'AWS-RunShellScript' `
    -Parameters @{
        commands=$script
     } `
    -Outputs3BucketName $S3Bucket












#Cleanup
Write-Host "`nTerminating instance" -ForegroundColor Yellow
#SSMRemoveInstance $instanceName



#SSMRemoveRole



#SSMRemoveKeypair




#SSMRemoveSecurityGroup 
