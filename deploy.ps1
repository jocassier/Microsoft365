[CmdletBinding()]
param (
    [Parameter()]
    [switch]
    $Test
)

#TODO - Setup prereqs loading Powershell Modules etc.

Write-Output -InputObject 'Setup LCM...'

Set-DscLocalConfigurationManager -Path '.\output\LCM' -Verbose

$configurations = Get-ChildItem -Path '.\output\workloads' -Recurse -Filter '*.mof' 

if($Test.IsPresent) 
{
    Write-Output -InputObject 'Test configurations against tenant...'

    Foreach($configuration in $configurations) 
    {
        Test-DscConfiguration -Path $configuration.DirectoryName
    }
}
else 
{
    Write-Output -InputObject 'Publish configurations to LCM...'

    Foreach($configuration in $configurations) 
    {
        Publish-DscConfiguration -Path $configuration.DirectoryName
    }

    Write-Output -InputObject 'Apply configurations to tenant...'

    Start-DscConfiguration -UseExisting -Wait -Verbose
}
