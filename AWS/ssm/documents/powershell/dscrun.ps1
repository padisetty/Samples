import-module -Global -Force "$PSScriptRoot\TestModule"
#$dest = "$($env:ProgramFiles)\WindowsPowerShell\Modules"
#$dest = "$($env:HOMEDRIVE)$($env:HOMEPATH)\Documents\WindowsPowerShell\Modules"
$dest = "$PSHOME\Modules"
robocopy "$PSScriptRoot\TestModule" "$dest\TestModule" /mir /NJH /NJS /NP /NFL /NDL
. "$PSScriptRoot\dsclocal.ps1"