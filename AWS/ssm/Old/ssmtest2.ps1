
New-WinEC2Instance -InstanceType 'c3.xlarge' `
    -IamRoleName 'role1' `
    -Name 'test1' `
    -NewPassword 'Secret.' `
    -SubnetId 'subnet-812e00a9' `
    -SecurityGroupName 'sg_winec2_vpc_172_16'


. C:\temp\ssm\ssmcommon.ps1
Set-DefaultAWSRegion 'us-east-1'
$doc = @"
{
  "schemaVersion": "1.0",
  "description": "MSI Test Example",
  "runtimeConfig": {
      "aws:applications": {
        "description": "UnInstall 7Zip and PS module for networking scripts",
        "properties": [
          {
            "action": "UnInstall",
            "extension": "MSI",
            "source": "http://downloads.sourceforge.net/sevenzip/7z920.msi"
          }
        ]
      }
   }
}
"@

function CreateDeleteAssociation ([string]$tag)
{
    $instance = Get-WinEC2Instance $tag
    $instanceid = $instance.InstanceId

    $name = 'CreateDelete-' + [Guid]::NewGuid()
    Write-Verbose "Document Name=$name"
    $null = New-SSMDocument -Name $name -Content $doc
    $null = New-SSMAssociation -InstanceId $instanceid -Name $name
    $association = Get-SSMAssociationList -AssociationFilterList @{Key='InstanceId'; Value=$instanceid}
    if (! $association)
    {
        throw 'Eventual consistency issue in association'
    }
    
    SSMDeleteAssociation $instanceid
    SSMDeleteDocument $name
}

function CreateDeleteDocument ([string]$tag)
{
    Write-Verbose "Tag=$tag"
    $instance = Get-WinEC2Instance $tag
    $instanceid = $instance.InstanceId

    $name = 'CreateDelete-' + [Guid]::NewGuid()
    Write-Verbose "Document Name=$name"
    $null = New-SSMDocument -Name $name -Content $doc
    $document = Get-SSMDocument -Name $name 
    if (! $document)
    {
        throw 'Eventual consistency issue in Document'
    }
    
    SSMDeleteDocument $name
}

1..1 | % { $_; CreateDeleteAssociation -tag 'Dev1' }

1..100 | % { $_; CreateDeleteDocument -tag 'Dev1' }

$cmd = {
    function downloadCookBook ([string]$name)
    {
        if (! (Test-Path "C:\chef\cookbooks\$name"))
        {
            knife cookbook site download $name 2>&1 | Out-Null
            $tar = (dir "$name*.tar.gz").Name
            tar -xf $tar | Out-Null
            del $tar
            move $name cookbooks
        }
    }
    $null = md c:\chef\cookbooks -ea 0
    cd c:\chef
    'cookbook_path  "c:/chef/cookbooks"' > c:\chef\client.rb
    'cookbook_path  "c:/chef/cookbooks"' > c:\chef\knife.rb
    downloadCookBook '7-zip'
    downloadCookBook 'windows'
    downloadCookBook 'chef_handler'
    chef-client -z -o 7-zip
}
icmwin test $cmd

icmwin test1 {Add-WindowsFeature 'RSAT-AD-PowerShell'} -Credential $cred
icmwin test1 {Get-WindowsFeature 'RSAT-AD-PowerShell'} -Credential $cred

icmwin test1 {Get-ADcomputer 'Win2'} -Credential $cred

icmwin test1 {dir c:\} -Credential $cred
icmwin test1 {dir c:\} 

$cmd = {
    Remove-Computer -UnjoinDomainCredential $using:cred -WorkgroupName 'Workgroup' -Restart -Force
}
icmwin test1 $cmd -Credential $cred

$cmd = {Rename-Computer -NewName 'Win5' -Restart}
icmwin test1 $cmd 
