#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

#configuration is like a function defination, you need to invoke main explicitly
configuration main
{
    node "localhost"
    {
        Log l1 { Message = "ONE" }
    }

    node "server2"
    {
        Log l2 { Message = "TWO" }
    }
}

#1 compile - call main to genrate MOF
Write-Host "`n1. Generating MOF localhost.mof, server2.mof" -ForegroundColor Yellow
main -OutputPath C:\temp\config 

#2 display localhost.mof
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 display server2.mof
Write-Host "`n3. Content of c:\temp\config\server2.mof" -ForegroundColor Yellow
cat C:\temp\config\server2.mof

#3 Apply - push the MOF file generated to the target node.
Write-Host "`n4. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose

#5 List MOF files generated
Write-Host "`n5. Generated following MOF files" -ForegroundColor Yellow
dir c:\temp\config