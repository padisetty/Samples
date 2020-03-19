Write-Verbose 'Install SSM Agent'

. "$PSScriptRoot\Common Setup.ps1"

$Name = "perf$Name"

$region = (Get-DefaultAWSRegion).Region


$data = Get-WinEC2Password $obj.'InstanceId'
$secpasswd = ConvertTo-SecureString $data.Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)

$connectionUri = "http://$($obj.'PublicIpAddress'):80/"
$obj.'ActivationId' =  SSMInstallAgent -ConnectionUri $connectionUri -Credential $cred -Region $region -DefaultInstanceName $Name
