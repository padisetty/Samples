param ([switch]$SkipDeletingOutput)

if (Test-PSTestExecuting) {
    Write-Verbose 'Skipping Common Setup as it is called inside PSTest'
} else {
    $VerbosePreference = 'Continue'
    Write-Verbose 'Common Setup'
    trap { break } #This stops execution on any exception
    $ErrorActionPreference = 'Stop'

    Import-Module -Global PSTest -Force -Verbose:$false
    . $PSScriptRoot\..\ssm\ssmcommon.ps1
}

