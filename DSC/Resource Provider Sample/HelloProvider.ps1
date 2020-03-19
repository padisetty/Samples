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
Write-Host "`n1. Generating MOF localhost.mof" -ForegroundColor Yellow
main -OutputPath C:\temp\config -ConfigurationData $data

#2 display the MOF file generated
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 Apply - push the MOF file generated to the target node.
Write-Host "`n3. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose -Force

#4 Discover the schema
Write-Host "`n4. Schema for Hello" -ForegroundColor Yellow
Get-DscResource -Name Hello -Syntax

#5 Get - Get current applied configuration
Write-Host "`n5. Get configuration from localhost" -ForegroundColor Yellow
Get-Process wmi* | Stop-Process -Force
$s = New-CimSession -ComputerName localhost
Get-DscConfiguration -CimSession $s -Verbose
Remove-CimSession $s

