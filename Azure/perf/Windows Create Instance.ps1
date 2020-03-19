# You should define before running this script.
#    $name - Name identifies logfile and test name in results
#            When running in parallel, name maps to unique ID.
#            Some thing like '0', '1', etc when running in parallel
#     $obj - This is a dictionary, used to pass output values
#            (e.g.) report the metrics back, or pass output values that will be input to subsequent functions

param ( $Name = '',
        $Region = 'West US',
        $InstanceType = 'Standard_D1_v2', # 'Medium', #'Small',
        $ImagePrefix='Windows Server 2012 R2'
        #$ImagePrefix='Windows Server 2016 Tech*'
        #$ImagePrefix='Windows Server 2016 Technical Preview 5 - Nano Server'
)

. "$PSScriptRoot\Common Setup.ps1"

$image = Get-AzureVMImage | ? label -Like "$ImagePrefix*"  | select -Last 1
Write-Verbose "Image = $($image.Label)"
if ($image -eq $null) {
    throw "Image with prefix $ImagePrefix not found"
}

$location = Get-AzureLocation | ? Name -EQ $Region
Write-Verbose "Location/Region = $($location.Name)"


$name = "mc-$(Get-Random)"
Write-Verbose "Service and Instance Name=$name"

#Given it is a test instance, and deleted right, the password is printed. Bad idea for real use case!
$password = "pass-$(Get-Random)"
Write-Verbose "Generated Password=$password"
$obj.'Password' = $password

$startTime = Get-Date
Write-Verbose "$($startTime) - Creating VM, will take 5+ minutes"
$null = New-AzureQuickVM -Windows -Name $name -ServiceName $name `
                     -Location $location.Name -ImageName $image.ImageName `
                     -InstanceSize $instanceType `
                     -AdminUsername "siva" -Password $password `
                     -EnableWinRMHttp  -WaitForBoot  
$runningTime = Get-Date
Write-Verbose "$($runningTime - $startTime) - Running"


#PowerShell Remoting
$uri = Get-AzureWinRMUri -Name $name -ServiceName $name
$obj.'ConnectionUri' = $uri.ToString()
Write-Verbose "Uri=$($obj.'ConnectionUri')"

#Skip Certificate Authority check
#This is because of generated certificate with no trusted root
$opts = New-PSSessionOption -SkipCACheck 

#create the securestring
$SecurePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$cred = New-Object PSCredential -ArgumentList "siva", $SecurePassword
do
{
    $processList = Invoke-Command -ConnectionUri $uri `
                   -Credential $cred `
                   -ScriptBlock {Get-Process} `
                   -SessionOption $opts
} while ($processList -eq $null -or $processList.Length -eq 0)

$remoteTime = Get-Date
Write-Verbose "$($remoteTime - $startTime) - Remote"

$Obj.'ServiceName' = $name
$Obj.'Region' = $Region
$Obj.'InstanceType' = $InstanceType
$Obj.'Image' = $image.Label
$Obj.'BootTime' = $runningTime - $startTime
$Obj.'RemoteTime' = $remoteTime - $startTime

