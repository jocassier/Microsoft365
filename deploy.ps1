[CmdletBinding()]
param (
    # [Parameter()]
    # [ValidateScript(
    #     { 
    #         $validValues = (Get-ChildItem -Path '.\output\workloads').BaseName
    #         foreach($value in $_) 
    #         {
    #             if($value -notin $validValues)
    #             {
    #                 throw "Valid values are $($validValues -join ', ')"
    #             }
    #         }
    #         return $true 
    #     }
    # )]
    # [String[]] 
    # $ConfigurationName = (Get-ChildItem -Path '.\output\workloads').BaseName,

    [Parameter()]
    [switch]
    $Test
)

#TODO - Setup prereqs loading Powershell Modules etc.

Write-Output -InputObject 'Setup LCM...'

Set-DscLocalConfigurationManager -Path '.\output\LCM' -Verbose

$configurations = Get-ChildItem -Path '.\output\workloads' -Recurse -Filter '*.mof' #| Where-Object -FilterScript {$_.Directory.Name -in $ConfigurationName}

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
    # Write-Output -InputObject 'Remove configuration documents from LCM...'

    # Remove-DscConfigurationDocument -Stage Current, Previous, Pending -Verbose -Force

    Write-Output -InputObject 'Publish configurations to LCM...'

    Foreach($configuration in $configurations) 
    {
        Publish-DscConfiguration -Path $configuration.DirectoryName
    }

    Write-Output -InputObject 'Apply configurations to tenant...'

    Start-DscConfiguration -UseExisting -Wait -Verbose
}
