# Author: Sivaprasad Padisetty
# Copyright 2013, Licensed under Apache License 2.0
#

function ApplyConfiguration ($Ensure = "Present")
{
    configuration WebConfig
    {
        WindowsFeature IIS
        {
            Name="Web-Server"
            Ensure=$Ensure
        }

        <#
        Package package7zip
        {
            #Path = "http://hivelocity.dl.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
            Path = 'https://downloads.sourceforge.net/project/sevenzip/7-Zip/16.04/7z1604-x64.msi'
            Name = "7-Zip 16.04 (x64 edition)"
            Ensure = "Present"
            ProductId = ""
        }
        Hello h
        {
            Message = "Hello World!!"
        }
        cCreateFileShare CreateShare
        {
            ShareName = 'temp'
            Path      = 'c:\temp'
            Ensure    = 'Present'
        }
        xHotfix m1
        {
            Uri = "http://hotfixv4.microsoft.com/Microsoft%20Office%20SharePoint%20Server%202007/sp2/officekb956056fullfilex64glb/12.0000.6327.5000/free/358323_intl_x64_zip.exe"
            Id = "KB956056" 
            Ensure="Present"
        }#>
    }
    md c:\temp -ea 0
    
    WebConfig -OutputPath C:\temp\config  -ConfigurationData $AllNodes
    
    Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose -force
    'ApplyConfiguration applied successfully!!!'
}

function ChefInstall ([string]$MSIPath)
{

    $recipe = @"
file 'c:/temp/helloworld.txt' do
  content 'hello world'
end

remote_file 'c:/temp/7zip.msi' do
  source "http://www.7-zip.org/a/7z938-x64.msi"
end

windows_package '7-Zip 9.38 (x64 edition)' do
  source 'c:/temp/7zip.msi'
  action :install
end
"@
    configuration ChefConfig
    {
        File SevenZip
        {
            DestinationPath = 'c:\temp\7zip.rb'
            Contents = $Recipe
        }
        Package ChefPackage
        {
            Path = $MSIPath
            Name = "Chef Client v12.3.0"
            Ensure = "Present"
            ProductId = ""
        }
    }

    ChefConfig -OutputPath C:\temp\config  -ConfigurationData $AllNodes
    Start-DscConfiguration c:\temp\config -ComputerName localhost -Wait -verbose -force

    C:\opscode\chef\bin\chef-apply.bat C:\temp\7zip.rb | Out-File 'c:\temp\chef-apply.log'
}

function Test1 ()
{
    'Hello this is test1 from SSMDemoModule'
}


function Test2 ()
{
    'Hello this is test2'
    if (! (Test-Path c:\test)) {
        'returning 3010, should continue after reboot'
        $null = md c:\test
        exit 3010 # Reboot requested
    } else {
        del c:\test -force
        'Test2 completed!!!'
    }
}

#ChefInstall -MSIPath 'https://opscode-omnibus-packages.s3.amazonaws.com/windows/2008r2/x86_64/chef-client-12.3.0-1.msi'
