#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

#configuration is like a function and can take parameters!
Configuration main
{
    param ($one)
    
    # merges config generated from multiple node tag
    node $AllNodes.Where{$_.Role -eq "Worker"}.NodeName
    {
        Log l1 { Message = "Environment=$($node.EnvironmentName)" }

        $global:p = $node.path
        WindowsProcess p1
        {
            Path = $node.path
            Arguments = ""
        }
    }
} 



#1 compile
Write-Host "`n1. Generating MOF c:\temp\config\localhost.mof" -ForegroundColor Yellow
main -OutputPath c:\temp\config -ConfigurationData "$psscriptroot\7.1 - AllNodes.psd1" -one "1"

#2 localhost.mof
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 apply
Write-Host "`n3. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose -force

#4 show the calc process
$p = $p.Replace(".exe","")       
Write-Host "`n4. Process $p" -ForegroundColor Yellow
Get-Process "$p" | % { "$p process id is $($_.Id)" }