#cleanup files, so that the script can be run multiples times
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0
md c:\temp\testfile

#This test expects a test certificate installed in My store.
#  Subject for this certificate should be 'CN=DSC Test Certificate'
$cert = dir Cert:\LocalMachine\My | where { $_.Subject -eq 'CN=DSC Test Certificate' }

if (-not $cert)
{
    # Certificate not found, so will try to create one
    if (gcm makecert.exe 2>$null)
    {
        #generates certificate and installs in the My store
        makecert -r -pe -n "CN=DSC Test Certificate" -sky exchange -ss my -sr localMachine
    }
    else
    {
        #If a pfx file is present in $PSScriptRoot or in current directory
        #import it into My Store


        #following commands are used to create pfxfile
        #It is precreated so script will run without makecert dependency
        #makecert -sky exchange -n "CN=DSC Test Certificate" -pe -sv "DSC Test Certificate.pvk" "DSC Test Certificate.cer"
        #pvk2pfx -pvk "DSC Test Certificate.pvk" -spc "DSC Test Certificate.cer" -pfx "DSC Test Certificate.pfx"  -pi password

        #Locate pfxfile
        $pfxfile  = dir "$psscriptroot\*DSC Test Certificate.pfx" | select -First 1
        if (-not $pfxfile) 
        {
            $pfxfile = dir ".\*DSC Test Certificate.pfx" | select -First 1
        }

        if  ($pfxfile)
        {
            $password = ConvertTo-SecureString -String "password" -Force –AsPlainText
            Import-PfxCertificate -FilePath $pfxfile -Exportable -Password $password `
                                    -CertStoreLocation Cert:\Localmachine\My
        }
        else
        {
            throw 'Did not find DSC Test Certificate, please install makecert.exe in the path'
        }
    }
    $cert = dir Cert:\LocalMachine\My | where { $_.Subject -eq 'CN=DSC Test Certificate' }
}


$certfile = 'c:\temp\testfile\DSC Test Certificate.cer'
Export-Certificate -Cert $cert -FilePath $certfile

#Config definition

configuration main
{ 
    node "localhost"
    {   
        $password = "Secret.1" | ConvertTo-SecureString -asPlainText -Force
        $username = "user1" 
        $cred = New-Object System.Management.Automation.PSCredential($username,$password)

        User u1
        {
            UserName = "$username";
            Password = $cred;
        }

        LocalConfigurationManager 
        {
            CertificateID = $cert.Thumbprint
        }
    }
}

$config=
@{
    AllNodes = @( 
                    @{  
                        NodeName = "localhost"
                        CertificateFile=$certfile
                    };
                );
}

#1 compile - call main to generate MOF
Write-Host "`n1. Generating MOF localhost.mof" -ForegroundColor Yellow
main -OutputPath C:\temp\config -ConfigurationData $config

#2 display the MOF file generated
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 display the meta.mof file generated
Write-Host "`n3. Content of c:\temp\config\localhost.meta.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.meta.mof

#4 Apply - push the MOF file generated to the target node.
Write-Host "`n4. Applying META configuration to localhost" -ForegroundColor Yellow
Set-DscLocalConfigurationManager -ComputerName localhost -Path C:\temp\config

#5 Apply - push the MOF file generated to the target node.
Write-Host "`n5. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose -Force
