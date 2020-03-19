#--------------------------------------------------------------------------------------------
#   Copyright 2011 Sivaprasad Padisetty
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http:#www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#--------------------------------------------------------------------------------------------


#https://ec2-54-242-89-137.compute-1.amazonaws.com/FederationMetadata/2007-06/FederationMetadata.xml
#http://blogs.aws.amazon.com/security/post/Tx71TWXXJ3UI14/Enabling-Federation-to-AWS-using-Windows-Active-Directory-ADFS-and-SAML-2-0
#http://docs.aws.amazon.com/STS/latest/UsingSTS/STSMgmtConsole-SAML.html 


#Prereq checks
#location where makecert tool is present, you can find this tool part of Windows SDK
$makecertpath = 'c:\temp\makecert.exe'
$domainname = "sivadomain.com"
$netbiosname = "sivadomain"
#for illustration password is hardcoded, best is to use Get-Credential
$password = ConvertTo-SecureString "Password123" -AsPlainText -Force

if ( !(Test-Path -Path $makecertpath))
{
    'makecertpath should point to full path of makecert.exe'
    return
}

if ((Get-Module AWSPowerShell) -eq $null)
{
    'AWSPowerShell is not installed'
    return
}

if ((Get-AWSCredentials -ListStoredCredentials | Select-String 'AWS PS Default') -eq $null)
{
    'AWS PS Default is not set. Run Initialize-AWSDefaults'
    Initialize-AWSDefaults -AccessKey AKIAJNPGMUOPUA4AS7DQ -SecretKey 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 -Region 'us-east-1'
    return
}

#Install the AD Forest, which creates the first domain controller.
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools

if ($env:userdomain -eq $env:computername)
{
    Install-ADDSForest –DomainName $domainname `
        -DomainNetbiosName $netbiosname `
        –DomainMode Win2012R2 –ForestMode `
        Win2012R2 –DatabasePath "C:\ADDATA\NTDS" `
        –SYSVOLPath "C:\ADDATA\SYSVOL" `
        –LogPath "C:\ADDATA\Logs" -Force `
        -SafeModeAdministratorPassword $password
    Restart-Computer
}

#Add new test user, that will used for SSO
New-ADUser -Name test -AccountPassword $password -EmailAddress "test@$domainname" -Enabled $true

#Create two groups and add test user to them
New-ADGroup AWS-Production -GroupScope Global  -GroupCategory Security
New-ADGroup AWS-Dev -GroupScope Global  -GroupCategory Security
Add-ADGroupMember -Identity AWS-Production -Members test
Add-ADGroupMember -Identity AWS-Dev -Members test

Install-WindowsFeature Web-Server, ADFS-Federation, Web-Scripting-Tools -IncludeManagementTools
Import-Module WebAdministration

#Add user account for ADFS service to run
New-ADUser -Name ADFSSVC -AccountPassword $password -Enabled $true
setspn -a host/localhost adfssvc

$adfsname = "adfs.$domainname"
#Generate Self signed Certificate

&$makecertpath -n "CN=$adfsname" -r -pe -sky exchange `
        -ss My -sr LocalMachine -eku 1.3.6.1.5.5.7.3.1
$sslcert = ,(Get-ChildItem 'Cert:\LocalMachine\My' `
        | Where-Object { $_.Subject -eq "CN=$adfsname" })[0]

$cred =  New-Object System.Management.Automation.PSCredential `
        ("$netbiosname\ADFSSVC", $password)
Install-AdfsFarm `
    -CertificateThumbprint $sslcert.Thumbprint `
    -FederationServiceDisplayName "Sivas ADFS" `
    -FederationServiceName $adfsname `
    -ServiceAccountCredential $cred `
    -OverwriteConfiguration

#verify https://localhost/adfs/fs/federationserverservice.asmx

Add-ADFSRelyingPartyTrust -Name "Amazon" `
        -MetadataUrl https://signin.aws.amazon.com/static/saml-metadata.xml

#Download and save the ADFS metadata to a tempfile
#Because of self signed, need to disable the SSL Validation
#   otherwise WebClient.DownloadFile will fail.
$url = "https://localhost/FederationMetadata/2007-06/FederationMetadata.xml"
$metadatapath =  [IO.Path]::GetTempFileName()
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$webClient = new-object System.Net.WebClient
$webClient.DownloadFile( $url, $metadatapath )

#Register a new SAML Provider with IAMS that has this ADFS information
$role = New-IAMSAMLProvider -Name "ADFS" -SAMLMetadataDocument (cat $metadatapath)
$account = $role.Substring(13,12)

del $metadatapath

#custom replacement is used for $role, so don't have to deal with escape chars
$trustPolicy = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRoleWithSAML",
      "Principal": {"Federated": "$role"},
      "Condition": {
        "StringEquals": {"SAML:aud": "https://signin.aws.amazon.com/saml"}
      }
    }
  ]
}
'@
$trustPolicy = $trustPolicy.Replace('$role', $role)

$accessPolicy = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["s3:Get*"],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
'@

New-IAMRole -AssumeRolePolicyDocument $trustPolicy -RoleName "ADFS-Production"
Write-IAMRolePolicy -RoleName "ADFS-Production" -PolicyName "EC2-Get-Access" -PolicyDocument $accessPolicy

New-IAMRole -AssumeRolePolicyDocument $trustPolicy -RoleName "ADFS-Dev"
Write-IAMRolePolicy -RoleName "ADFS-Dev" -PolicyName "EC2-Get-Access" -PolicyDocument $accessPolicy

$nameId = @'
    @RuleTemplate = "MapClaims"
    @RuleName = "Name ID"
    c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/primarysid"]
        => 
    issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", 
        Issuer = c.Issuer, 
        OriginalIssuer = c.OriginalIssuer, 
        Value = c.Value, 
        ValueType = c.ValueType, 
        Properties["http://schemas.xmlsoap.org/ws/2005/05/identity/claimproperties/format"] 
                                        = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent");
'@

$roleSessionName = @'
    @RuleTemplate = "LdapClaims" 
    @RuleName = "RoleSessionName" 
    c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", 
        Issuer == "AD AUTHORITY"]
        => 
    issue(store = "Active Directory", 
        types = ("https://aws.amazon.com/SAML/Attributes/RoleSessionName"), 
        query = ";mail;{0}", param = c.Value);
'@

#list of AD groups is first stored in a temporary variables
$tempVariable = @'
    @RuleName = "Save AD Group Into http://temp/variable"
    c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", 
        Issuer == "AD AUTHORITY"]
        => 
    add(store = "Active Directory", 
        types = ("http://temp/variable"), 
        query = ";tokenGroups;{0}", 
        param = c.Value);
'@

$roleMapping = @'
    @RuleName = "Role mapping"
    c:[Type == "http://temp/variable", Value =~ "(?i)^AWS-"]
        => 
    issue(Type = "https://aws.amazon.com/SAML/Attributes/Role", Value = 
        RegExReplace(c.Value, "AWS-", 
        "arn:aws:iam::$account:saml-provider/ADFS,arn:aws:iam::$account:role/ADFS-"));
'@

$roleMapping = $roleMapping.Replace('$account', $account)
$ruleset = New-AdfsClaimRuleSet -ClaimRule $nameId,$roleSessionName, $tempVariable, $roleMapping

$issuanceAuthorizationRules = @'
    @RuleTemplate = "AllowAllAuthzRule"
        => 
    issue(Type = "http://schemas.microsoft.com/authorization/claims/permit", 
        Value = "true");
'@
Set-ADFSRelyingPartyTrust -TargetName Amazon -IssuanceTransformRules $ruleset.ClaimRulesString -IssuanceAuthorizationRules $issuanceAuthorizationRules


#Test by logging in at https://localhost/adfs/ls/IdpInitiatedSignOn.aspx
start https://localhost/adfs/ls/IdpInitiatedSignOn.aspx


#cleanup, requires multiple reboots, so needs to be executed in chunks.
if ($false)
{
    Remove-IAMRolePolicy -RoleName "ADFS-Production" -PolicyName "EC2-Get-Access" -Force
    Remove-IAMRole -RoleName "ADFS-Production" -Force

    Remove-IAMRolePolicy -RoleName "ADFS-Dev" -PolicyName "EC2-Get-Access" -Force
    Remove-IAMRole -RoleName "ADFS-Dev" -Force

    #For some reason this is not working.
    #$arn = Get-IAMSAMLProviders | where { $_.Arn -like '*/ADFS' } | select Arn
    #Remove-IAMSAMLProvider -SAMLProviderArn $arn -Force -Verbose 

    Remove-WindowsFeature Web-Server, ADFS-Federation, Web-Scripting-Tools -Restart:$false
  
    Uninstall-ADDSDomainController -ForceRemoval -LocalAdministratorPassword $password -DemoteOperationMasterRole -Force -NoRebootOnCompletion | fl
    Remove-WindowsFeature AD-Domain-Services, DNS 
}