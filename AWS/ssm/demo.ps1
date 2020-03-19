$password = (get-SSMParameterValue -Name 'password' -WithDecryption:$true).Parameters[0].Value
$admin=[adsi]("WinNT://$env:computername/administrator, user")
$admin.psbase.invoke('SetPassword', $password)
'Password set successfully'