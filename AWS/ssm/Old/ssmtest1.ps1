# You should define before running this script.
#    $name - You can create some thing like '1', '2', '3' etc for each session
param ([string]$name = '')

if ($name.Length -eq 0)
{
    $name = (Get-Item $MyInvocation.MyCommand.Path).BaseName
    if ((Get-Host).Name.Contains(' ISE '))
    {
        $parts = $psise.CurrentPowerShellTab.DisplayName.Split(' ')
        $name += $parts[$parts.Length - 1]
    }
}

Write-Verbose "Name=$name"
$DefaultRegion = 'us-east-1'


Import-Module -Global WinEC2 -Force -Verbose:$false
Import-Module -Global PSTest -Force -Verbose:$false

Set-DefaultAWSRegion $DefaultRegion


$VerbosePreference = 'Continue'
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
cd c:\temp

$doc = @"
{
  "schemaVersion": "1.0",
  "description": "MSI Test Example",
  "runtimeConfig": {
      "aws:applications": {
        "description": "Install 7Zip and PS module for networking scripts",
        "properties": [
          {
            "action": "Install",
            "extension": "MSI",
            "source": "http://downloads.sourceforge.net/sevenzip/7z920.msi"
          }
        ]
      }
   }
}
"@



function Cleanup ()
{
    try
    {
        DeleteDocument
    }
    catch
    {
    }
}

function CreateDocument ()
{
    New-SSMDocument -Content $doc -Name $name
}


function DeleteDocument ()
{
    Remove-SSMDocument -Name $name -Force
}

function CreateDeleteLoop ()
{
    for ($i=0; $i -lt 100; $i++)
    {
        "$i Create and Delete"
        $null = CreateDocument
        DeleteDocument   
    }
}

Invoke-PsTestRandomLoop -Name $name `
    -Tests @('Cleanup', 'CreateDeleteLoop') `
    -Parameters @{ 
    } `
    -ContinueOnError:$false `
    -MaxCount 1
