#cleanup if present
del C:\temp\testfile -Force -Recurse -ea 0
del C:\temp\config -Force -Recurse -ea 0

#Demonstrantes a reusable module

configuration NotepadConfig
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $workingdirectory
        )

    # Process resource to start notepad
    WindowsProcess p1
    {
        Path = "notepad.exe"
        Arguments = ""
        WorkingDirectory = $workingdirectory
        #Credential = $cred
    }
}