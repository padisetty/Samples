#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

Import-Module "$psscriptroot\4.1 - Notepad.psm1" -Force

#configuration is like a function defination, you need to invoke main explicitly
configuration main
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $root
    )

    Log l1 { Message = "Root is $root" }
    
    #invoking a reusable module
    NotepadConfig -workingdirectory "$root\temp"
}


#1 compile - call main to genrate MOF
Write-Host "`n1. Generating MOF localhost.mof" -ForegroundColor Yellow
main -OutputPath C:\temp\config -root "c:"

#2 display the MOF file generated
Write-Host "`n2. Content of c:\temp\config\localhost.mof" -ForegroundColor Yellow
cat C:\temp\config\localhost.mof

#3 Apply - push the MOF file generated to the target node.
Write-Host "`n3. Applying configuration to localhost" -ForegroundColor Yellow
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose

#4 Get the notepad process
Write-Host "`n4. Notepad process:" -ForegroundColor Yellow
Get-Process *notepad* | % { "Notepad process id is $($_.Id)" }
