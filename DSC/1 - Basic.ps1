#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

#configuration is like a function defination, you need to invoke main explicitly
#Each resource is associated with a schema and imperative provider
configuration main
{
    #Log resource
    Log l1 { 
        Message = "HELLO WORLD" 
    }


    #stops the "Computer Browser" service.
    Service browser
    {
        Name = "Browser"
        StartupType = "Manual"
        State = "Stopped"
    }
}

#1 compile - call main to genrate MOF
Write-Host "`n1. Generating MOF localhost.mof" -ForegroundColor Yellow
main -OutputPath C:\temp\config 

#2 display the MOF file generated
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 Apply - push the MOF file generated to the target node.
Write-Host "`n3. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose -Force

#4 Discover the schema
Write-Host "`n4. Schema for Service" -ForegroundColor Yellow
Get-DscResource -Name Service -Syntax

#5 Location of WindowsFeature provider
Write-Host "`n5. Service is located at" -ForegroundColor Yellow
dir C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PSDesiredStateConfiguration\DSCResources\MSFT_ServiceResource
