function Get-TargetResource
{
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[Parameter(Mandatory)]
		[String]$Message
	)
	$returnValue = @{
		Message = $Message
	}
	$returnValue
}


function Set-TargetResource
{
	param
	(
		[Parameter(Mandatory)]
		[String]$Message
        )
    
    Write-Verbose "Message: $Message"
}


function Test-TargetResource
{
	[OutputType([System.Boolean])]
	param
	(
		[Parameter(Mandatory)]
		[String]$Message
	)
    $false # Hello providers always returns false, that means allways SET is called.
}