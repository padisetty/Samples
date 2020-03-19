param ($instance, $cred)
Write-Host "Domain Join" -ForegroundColor Yellow
Write-Verbose "InstanceId=$($instance.InstanceId)"
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
. .\ssmcommon.ps1

function AutoDomainJoin (
    $Instance, 
    [string]$DirectoryId, 
    [string]$DirectoryName, 
    [string]$DNSIP1, 
    [string]$DNSIP2,
    [string]$AdminUser) #User to be added to the administrators group
{
    $doc = @"
    {
      "schemaVersion": "1.0",
      "description": "Auto Domain Join",
      "runtimeConfig": {
          "aws:domainJoin": {
            "properties": {
                "directoryId": "$DirectoryId",
                "directoryName": "$DirectoryName",
                "dnsIPAddresses": [
                    "$DNSIP1",
                    "$DNSIP2"
                ]
              }
          },
          "aws:psModule": {
            "description": "Install and run ps modules.",
            "properties": [
              {
                "runCommand": "net localgroup administrators $AdminUser /add"
              }
            ]
          }
       }
    }
"@

    SSMAssociate $instance $doc -RetrySeconds 300 -Credential $cred
}

$d = Get-DSDirectory | select -First 1


AutoDomainJoin -Instance $instance `
    -DirectoryId $d.DirectoryId `
    -DirectoryName $d.Name `
    -DNSIP1 $d.DnsIpAddrs[0] `
    -DNSIP2 $d.DnsIpAddrs[1] `
    -AdminUser "$($d.ShortName)\\siva"
