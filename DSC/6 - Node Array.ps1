#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

#configuration is like a function defination, you need to invoke main explicitly
configuration main
{
    param ($nodes)

    node $nodes
    {
        Log l1 { Message = "ONE" }
    }

    node ("localhost", "server2")
    {
        Log l2 { Message = "TWO" }
    }
}

#1 compile - call main to genrate MOF
Write-Host "`n1. Generating MOF localhost.mof, server1.mof, server2.mof" -ForegroundColor Yellow
main -OutputPath C:\temp\config -nodes ("localhost", "server1")

#2 display localhost.mof
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 display server1.mof
Write-Host "`n3. Content of c:\temp\config\server1.mof" -ForegroundColor Yellow
cat C:\temp\config\server1.mof

#4 display server2.mof
Write-Host "`n4. Content of c:\temp\config\server2.mof" -ForegroundColor Yellow
cat C:\temp\config\server2.mof

#3 Apply - push the MOF file generated to the target node.
Write-Host "`n5. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose

#6 List MOF files generated.
Write-Host "`n6. Following MOF files generated" -ForegroundColor Yellow
dir c:\temp\config