param ($instance, $cred)
Write-Host "MSI $productName" -ForegroundColor Yellow
Write-Verbose "InstanceId=$($instance.InstanceId)"
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
. .\ssmcommon.ps1

function InstallMSI ($instance, $Source, $ProductName)
{
    $doc = @"
    {
      "schemaVersion": "1.0",
      "description": "MSI Test Example",
      "runtimeConfig": {
          "aws:applications": {
            "description": "Install $ProductName and PS module for networking scripts",
            "properties": [
              {
                "action": "Install",
                "extension": "MSI",
                "source": "$Source"
              }
            ]
          }
       }
    }
"@
    Write-Verbose "Install $ProductName instanceid=$($instance.InstanceId)"
    SSMAssociate $instance $doc -Credential $cred
    
    $cmd = {
        $cmd1 = {gwmi win32_product | where { $_.Name -like $using:ProductName} | select Name }
        $programs = icm $instance.PublicIpAddress $cmd1 -Credential $cred -Port 80
        $programs -ne $null
    }
    $null = SSMWait $cmd -Message "$ProductName Install" -RetrySeconds 15
}

function UninstallMSI ($instance, $Source, $ProductName)
{
    $doc = @"
    {
      "schemaVersion": "1.0",
      "description": "MSI Test Example",
      "runtimeConfig": {
          "aws:applications": {
            "description": "UnInstall $ProductName and PS module for networking scripts",
            "properties": [
              {
                "action": "UnInstall",
                "extension": "MSI",
                "source": "$source"
              }
            ]
          }
       }
    }
"@
    Write-Verbose "UnInstall $ProductName instanceid=$($instance.InstanceId)"
    SSMAssociate $instance $doc -Credential $cred

    $cmd = {
        $cmd1 = {gwmi win32_product | where { $_.Name -like $using:ProductName} | select Name }
        $programs = icm $instance.PublicIpAddress $cmd1 -Credential $cred -Port 80
        $programs -eq $null
    }
    $null = SSMWait $cmd -Message "$ProductName Uninstall" -RetrySeconds 15 
}

$source = 'http://downloads.sourceforge.net/sevenzip/7z938.msi'
$productName = '7-Zip 9.38'

InstallMSI $instance $source $productName
UninstallMSI $instance $source $productName
