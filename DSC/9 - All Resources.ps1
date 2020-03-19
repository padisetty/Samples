#The following assembly has compression function used later.
[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")

$scriptsource = $MyInvocation.MyCommand.Definition
#configuration is like a function defination
configuration main
{
    node "localhost"
    {
        if ((gcm get-windowsfeature -ea 0) -ne $null) #checks if it is a server
        {
            #Install the IIS role.
            WindowsFeature IIS
            {
                    Name="Web-Server"
                    Ensure="Present"
            }
        }

        # Process resource to start notepad
        WindowsProcess p1
        {
            Path = "notepad.exe"
            Arguments = ""
            #Credential = $cred
        }

        #Create a file x.txt
        File f
        {
            SourcePath = $scriptsource
            DestinationPath = "c:\temp\TestFile\x.txt"
        }

        # Service resource, set it to manual
        Service browser
        {
            Name = "Browser"
            StartupType = "Manual"
        }
        #Creates the user
        $PlainPassword = "Password."
        $SecurePassword = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force 
        $UserName = "u1"
        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
        User u1
        {
           # PSDscAllowPlainTextPassword = $true
            UserName = "u1"
            Password = $cred
            Disabled = $false # There might be a bug here. Re application throws an error.
        }

        #create a group and administrator and u1 created above to it.
        Group group1
        {
            GroupName = "group1"
            Members = ("Administrator", "u1")
            DependsOn = "[User]u1"
        }

        #archive expands a zip file. 
        #first letus create a zip and use it for archive provider
        $zip = "c:\temp\TestFile.zip"
        if (!(Test-path -Path $zip))
        {

            [System.IO.Compression.ZipFile]::CreateFromDirectory($PSScriptRoot, $zip)
        }

        archive archive1
        {
            Path = "c:\temp\TestFile.zip"
            Destination = "c:\temp\TestFileFromArchivede"
        }

        #Environment 
        Environment testenv
        {
            Name = "TestEnv"
            Value = "TestValue"
            Ensure = "Present"
        }


        Log l1
        {
            Message = "This is a message from log provider."
        }


        #Registry
        
        Registry testreg
        {
            Key = "HKLM:\SOFTWARE\Microsoft"
            ValueName = "Test"
            ValueData = "TestValue"
            ValueType = "String"
            Ensure = "Present"
        }
<#

        Package My7ZipPackage
        {
            Path = "http://hivelocity.dl.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
            Name = "7-Zip 9.22 (x64 edition)"
            Ensure = "Present"
            ProductId = ""
        }
        #>


        #Script Resource
        $x = "X123"
        Script script1
        {
            GetScript = {$true}

            SetScript = {
                write-verbose "$using:x testing....."
                echo "Hello World1!" > C:\temp\TestFile\Hello1.txt
                $true
            }
            TestScript = {$false}
        }

    } # end of node tag
}

$AllNodes=
@{
    AllNodes = @(     
                    @{  
                    NodeName = "localhost";
                    PSDscAllowPlainTextPassword = $true;
                    };                                                                                     
                );    
}

#call testconfig to genrate MOF
main -OutputPath C:\temp\config  -ConfigurationData $AllNodes

#display the MOF file generated
cat C:\temp\config\localhost.mof

#push the MOF file generated to the target node.
Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose -force


#testing if some of the config changes happeneded.

echo ''
echo 'Checking the folder temp...'
dir c:\temp | ft

echo ''
echo 'Checking if notepad is started...'
Get-Process *notepad* | ft

echo ''
echo 'Checking the browser service state...'
gcim win32_service -Filter "Name='browser'" | ft

echo ''
echo 'Checking the useraccount'
gcim win32_useraccount -Filter "Name='u1'" | ft

echo ''
echo 'Checking the group'
gcim win32_groupuser | where { $_.GroupComponent.Name -eq 'group1' } | ft

dir C:\temp\TestFile\hello1.txt

echo ''
echo 'Content of the file is:'
cat C:\temp\TestFile\hello1.txt