#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding()]
param (
    # Parameter help description
    [Parameter()]
    [string]
    $Environment
)

######## BUILD PREREQUISITES ########

Set-Location -Path $PSScriptRoot

if (Test-Path -Path '.\output') {
    Remove-Item -Path '.\output' -Recurse -Force
}

New-Item -Path '.\output' -ItemType Directory | Out-Null

Write-Verbose -Message "Switching to path: $PSScriptRoot"

if (($env:PSModulePath -like "*$($PSScriptRoot)*") -eq $false) {
    Write-Verbose -Message "Switching to path: $PSScriptRoot"
    $env:PSModulePath = $env:PSModulePath.TrimEnd(";") + "$([IO.Path]::PathSeparator)$($PSScriptRoot)"
}

Write-OutPut -InputObject "Compile configuration(s)"

$environments = ConvertFrom-Yaml -Yaml (Get-Content -Path '.\Enviroments.yml' -Raw)

$configurations += Get-ChildItem -Path ".\source\workloads\" -Recurse -Filter '*.ps1' 

foreach ($environment in $environments.keys) {

    foreach ($configuration in $configurations) {

        . $configuration.FullName
        $expression = "$($configuration.BaseName) -OutputPath '.\output\$environment\$($configuration.BaseName)'"
        Write-Output -InputObject $expression
        Invoke-Expression -Command $expression | Out-Null
    }
}

Write-Output -InputObject "Get credentials"
if ($local.IsPresent) {
    Write-Output -InputObject "Use fake secret for local build"
}
else {
    Write-Output -InputObject "Get secrets from Azure KeyVault"
}

Write-OutPut -InputObject "Compile lcm configuration"
$lcm = Get-Item -Path '.\source\LCM.ps1'

. $lcm.FullName
$lcmExpression = "$($lcm.BaseName) -OutputPath '.\output\$($lcm.BaseName)' -PartialConfiguration $($configurations.BaseName -join ',')"
Write-Output -InputObject $lcmExpression
Invoke-Expression -Command $lcmExpression | Out-Null

Copy-Item -Path '.\dependencies.psd1', '.\deploy.ps1', '.\Enviroments.yml', '.\helpers.ps1', '.\monitor.ps1' -Destination '.\output'

# if ($modules.ContainsKey("Microsoft365Dsc"))
# {
#     Write-Log -Message 'Checking Microsoft365Dsc version'

#     $currentVersion = $modules.Microsoft365Dsc
#     $localModule = Get-Module 'Microsoft365Dsc' -ListAvailable

#     Write-Log -Message "Required version: $currentVersion" -Level 1
#     Write-Log -Message "Installed version: $($localModule.Version)" -Level 1

#     if ($localModule.Version -ne $currentVersion)
#     {
#         if ($null -ne $localModule)
#         {
#             Write-Log -Message 'Incorrect version installed.' -Level 1
#             Write-Log -Message 'Uninstall Microsoft365DSC' -Level 2
#             Uninstall-Module -Name $localModule.Name -Force
#         }

#         Write-Log -Message 'Configuring PowerShell Gallery' -Level 2
#         Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
#         [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#         $psGetModule = Get-Module -Name PowerShellGet -ListAvailable | Select-Object -First 1
#         if ($null -eq $psGetModule)
#         {
#             Write-Log -Message '* Installing PowerShellGet' -Level 3
#             $null = Install-Module PowerShellGet -SkipPublisherCheck -Force
#         }
#         else
#         {
#             if ($psGetModule.Version -lt [System.Version]"2.2.4.0")
#             {
#                 Write-Log -Message '* Installing PowerShellGet' -Level 3
#                 $null = Install-Module PowerShellGet -SkipPublisherCheck -Force
#             }
#         }

#         Write-Log -Message 'Installing Microsoft365Dsc' -Level 2
#         $null = Install-Module -Name 'Microsoft365Dsc' -RequiredVersion $psGalleryVersion
#     }
#     else
#     {
#         Write-Log -Message 'Correct version installed, continuing.' -Level 1
#     }

#     Write-Log -Message 'Modules installed successfully!'
# }
# else
# {
#     Write-Log "[ERROR] Unable to find Microsoft365Dsc in DscResources.psd1. Cancelling!"
#     Write-Error "Build failed!"
#     Write-Host "##vso[task.complete result=Failed;]Failed"
#     exit 10
# }

# ######## BUILD  ########

# Write-Log -Message ' '
# Write-Log -Message 'Start MOF compilation'

# # workload configurations
# $configurations = @()

# foreach($workload in $Workloads) 
# {
#     $configurations += Get-ChildItem -Path ".\source\workloads\$workload" -Filter '*.ps1' 
# }

# foreach($configuration in $configurations) 
# {
#     Write-Log -Message "Processing: $($configuration.BaseName)" -Level 1
#     . $configuration.FullName
#     $null = (Invoke-Expression -Command "$($configuration.BaseName) -OutputPath .\output\workloads\$($configuration.BaseName)")
# }

# # lcm configuration
# $lcm = Get-ChildItem -Path '.\source\lcm\LCM.ps1'

# Write-Log -Message "Processing: $($lcm.BaseName)" -Level 1
# . $lcm.FullName
# $null = Invoke-Expression -Command "$($lcm.BaseName) -PartialConfiguration $($configurations.BaseName -join ',') -OutputPath .\output\lcm"

# Write-Log -Message ' '
# Write-Log -Message '*********************************************************'
# Write-Log -Message '*      Finished M365 DSC Configuration Compilation      *'
# Write-Log -Message '*********************************************************'