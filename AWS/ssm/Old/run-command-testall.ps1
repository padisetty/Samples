#$Region = 'us-east-1'
#$S3Bucket = 'sivaiadbucket'
$Region = 'us-west-2'
$S3Bucket = 'sivapdxbucket'

cd $PSScriptRoot

for ($i=1; $i -le 5; $i++) {
#    Write-Host "`nIteration Number=$i" -ForegroundColor Yellow
#    .\run-command-linux.ps1 -ImageName 'amzn-ami-hvm-*gp2' -Region $Region -S3Bucket $S3Bucket

#    Write-Host "`nIteration Number=$i" -ForegroundColor Yellow
#    .\run-command-linux.ps1 -ImageName 'ubuntu/images/hvm-ssd/ubuntu-*-14.*' -Region $Region -S3Bucket $S3Bucket

    Write-Host "`nIteration Number=$i" -ForegroundColor Yellow
    .\run-command-windows.ps1 -ImageName 'WINDOWS_2012R2_BASE' -Region $Region -S3Bucket $S3Bucket
}
