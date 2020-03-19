param ($instance, $cred)
Write-Host "PSModule" -ForegroundColor Yellow
Write-Verbose "InstanceId=$($instance.InstanceId)"
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
. .\ssmcommon.ps1

if (! $instance)
{
   throw 'Instance is null'
}

function ExecutePSModule ($Instance, $ModulePath, $RunCommand)
{
    $properties = ''
    if ($ModulePath)
    {
        $properties += @"
                "source": "$ModulePath"
"@
    }

    if ($RunCommand)
    {
        if ($properties.Length -gt 0)
        {
            $properties += ",`n"
        }
        $properties += @"
                "runCommand": $RunCommand
"@
    }

    $doc = @"
    {
      "schemaVersion": "1.0",
      "description": "MSI Test Example",
      "runtimeConfig": {
          "aws:psModule": {
            "description": "Install and run ps modules.",
            "properties": [
              {
                $properties
              }
            ]
          }
       }
    }
"@
    SSMAssociate $instance $doc -RetrySeconds 600 -Credential $cred
}

$runCmd = @'
[
    "$url = 'https://chocolatey.org/install.ps1'",
    "iex ((new-object net.webclient).DownloadString($url))",
    "choco install googlechrome -y",
    "choco install 7zip -y"
]
'@

ExecutePSModule -Instance $instance `
    -ModulePath 'https://s3.amazonaws.com/sivabuckets3/public/PSDemo.zip' `
    -RunCommand $runCmd

ExecutePSModule -Instance $instance `
    -RunCommand $runCmd

ExecutePSModule -Instance $instance `
    -ModulePath 'https://s3.amazonaws.com/sivabuckets3/public/PSDemo.zip'

