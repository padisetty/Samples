#0 winrm quickconfig
echo "`n0. winrm quickconfig (needed to enable Start-DscConfiguration)"

winrm quickconfig -force

import-module -Global -Force "TestModule"

#cleanup
del C:\temp\config\* -Force -Recurse -ea 0

#Make sure HelloProvider module is copied to "$env:ProgramFiles\WindowsPowerShell\Modules"

#configuration is like a function defination, you need to invoke main explicitly
#Each resource is associated with a schema and imperative provider
configuration main
{
    Import-DscResource -Name Hello
    Node "localhost"
    {
        Hello h
        {
            
            Message = "Hello World!!"
            UserCredential = New-Object System.Management.Automation.PSCredential -ArgumentList "Administrator", (ConvertTo-SecureString -String "test" -AsPlainText -Force)
        }
    }
}


$data=
@{
    AllNodes = @(     
                    @{  
                    NodeName = "localhost";
                    PSDscAllowPlainTextPassword = $true;
                    };                                                                                     
                );    
}

#1 compile - call main to genrate MOF
echo "`n1. Generating MOF localhost.mof"
main -OutputPath C:\temp\config -ConfigurationData $data

#2 Apply - push the MOF file generated to the target node.
echo "`n2. Applying configuration to localhost"
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -Force -Verbose


