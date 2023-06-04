#TODO - Setup prereqs loading Powershell Modules etc.

Write-Output -InputObject 'Setup LCM...'

Set-DscLocalConfigurationManager -Path '.\output\LCM' -Verbose

$configurations = Get-ChildItem -Path '.\output\workloads' -Recurse -Filter '*.mof' 

Write-Output -InputObject 'Test configurations against tenant...'

Foreach($configuration in $configurations) 
{
    Test-DscConfiguration -Path $configuration.DirectoryName
}