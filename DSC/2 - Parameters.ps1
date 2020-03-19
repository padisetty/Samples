#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

#configuration is like a function, hence supports parameters
configuration main
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $content
    )

    File file
    {
        Contents = $content
        DestinationPath = "c:\temp\TestFile\x.txt"
    }        
}


#1 compile - call main to genrate MOF
Write-Host "`n1. Generating MOF localhost.mof" -ForegroundColor Yellow
main -OutputPath C:\temp\config -content "Hello World!"

#2 display the MOF file generated
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 Apply - push the MOF file generated to the target node.
Write-Host "`n3. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose

#4 Check generated file x.txt
Write-Host "`n4. Content of C:\temp\TestFile\x.txt is" -ForegroundColor Yellow
cat C:\temp\TestFile\x.txt
