#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

#supports imperative logic
configuration main
{
    param (
        [System.String]
        $message
    )

    #conditionally generate resource definition
    if ($message)
    {
        Log l1 { Message = $message }
    }

    #looping to generate multiple resource definitions    
    for ($i = 1; $i -le 3; $i++)
    { 
        File "f$i"
        {
            Contents = "Hello $i"
            DestinationPath = "c:\temp\TestFile\x$i.txt"
        }        
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
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose

#4 List the files created
Write-Host "`n4. Files created in c:\temp\TestFile" -ForegroundColor Yellow
dir C:\temp\TestFile | % { $_.FullName }
