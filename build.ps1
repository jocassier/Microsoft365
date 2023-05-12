[CmdletBinding()]
param (
    [Parameter()]
    [ValidateScript(
        { 
            $validValues = (Get-ChildItem -Path '.\source\workloads').BaseName
            foreach($value in $_) 
            {
                if($value -notin $validValues)
                {
                    throw "Valid values are $($validValues -join ', ')"
                }
            }
            return $true 
        }
    )]
    [String[]] 
    $Workloads = (Get-ChildItem -Path '.\source\workloads' -Directory).BaseName
)

######## FUNCTIONS ########
function Write-Log
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Message,

        [Parameter()]
        [System.Int32]
        $Level = 0
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $indentation = '  ' * $Level
    $output = "[{0}] - {1}{2}" -f $timestamp, $indentation, $Message
    Write-Host $output
}

######## VARIABLES ########

$outPutFolder = 'output'

######## PURGE OUTPUT DIRECTORY ########

if(Test-Path -Path $outPutFolder)
{
    Remove-Item -Path $outPutFolder -Recurse -Force
}

######## BUILD PREREQUISITES ########

if ($PSVersionTable.PSVersion.Major -ne 5)
{
    Write-Log -Message 'You are not using PowerShell v5.'
    return
}

Write-Log -Message '*********************************************************'
Write-Log -Message '*      Starting M365 DSC Configuration Compilation      *'
Write-Log -Message '*********************************************************'
Write-Log -Message ' '

Set-Location -Path $PSScriptRoot

Write-Log -Message "Switching to path: $PSScriptRoot"
Write-Log -Message ' '

if (($env:PSModulePath -like "*$($PSScriptRoot)*") -eq $false)
{
    Write-Log -Message "Adding current folder to PSModulePath"
    $env:PSModulePath = $env:PSModulePath.TrimEnd(";") + "$([IO.Path]::PathSeparator)$($PSScriptRoot)"
}

Write-Log -Message 'Checking for presence of Microsoft365Dsc module and all required modules'
Write-Log -Message ' '

$modules = Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath 'DscResources.psd1')

if ($modules.ContainsKey("Microsoft365Dsc"))
{
    Write-Log -Message 'Checking Microsoft365Dsc version'

    $currentVersion = $modules.Microsoft365Dsc
    $localModule = Get-Module 'Microsoft365Dsc' -ListAvailable

    Write-Log -Message "Required version: $currentVersion" -Level 1
    Write-Log -Message "Installed version: $($localModule.Version)" -Level 1

    if ($localModule.Version -ne $currentVersion)
    {
        if ($null -ne $localModule)
        {
            Write-Log -Message 'Incorrect version installed.' -Level 1
            Write-Log -Message 'Uninstall Microsoft365DSC' -Level 2
            Uninstall-Module -Name $localModule.Name -Force
        }

        Write-Log -Message 'Configuring PowerShell Gallery' -Level 2
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $psGetModule = Get-Module -Name PowerShellGet -ListAvailable | Select-Object -First 1
        if ($null -eq $psGetModule)
        {
            Write-Log -Message '* Installing PowerShellGet' -Level 3
            $null = Install-Module PowerShellGet -SkipPublisherCheck -Force
        }
        else
        {
            if ($psGetModule.Version -lt [System.Version]"2.2.4.0")
            {
                Write-Log -Message '* Installing PowerShellGet' -Level 3
                $null = Install-Module PowerShellGet -SkipPublisherCheck -Force
            }
        }

        Write-Log -Message 'Installing Microsoft365Dsc' -Level 2
        $null = Install-Module -Name 'Microsoft365Dsc' -RequiredVersion $psGalleryVersion
    }
    else
    {
        Write-Log -Message 'Correct version installed, continuing.' -Level 1
    }

    Write-Log -Message 'Modules installed successfully!'
}
else
{
    Write-Log "[ERROR] Unable to find Microsoft365Dsc in DscResources.psd1. Cancelling!"
    Write-Error "Build failed!"
    Write-Host "##vso[task.complete result=Failed;]Failed"
    exit 10
}

######## BUILD  ########

Write-Log -Message ' '
Write-Log -Message 'Start MOF compilation'

# workload configurations
$configurations = @()

foreach($workload in $Workloads) 
{
    $configurations += Get-ChildItem -Path ".\source\workloads\$workload" -Filter '*.ps1' 
}

foreach($configuration in $configurations) 
{
    Write-Log -Message "Processing: $($configuration.BaseName)" -Level 1
    . $configuration.FullName
    $null = (Invoke-Expression -Command "$($configuration.BaseName) -OutputPath .\output\workloads\$($configuration.BaseName)")
}

# lcm configuration
$lcm = Get-ChildItem -Path '.\source\lcm\LCM.ps1'

Write-Log -Message "Processing: $($lcm.BaseName)" -Level 1
. $lcm.FullName
$null = Invoke-Expression -Command "$($lcm.BaseName) -PartialConfiguration $($configurations.BaseName -join ',') -OutputPath .\output\lcm"

Write-Log -Message ' '
Write-Log -Message '*********************************************************'
Write-Log -Message '*      Finished M365 DSC Configuration Compilation      *'
Write-Log -Message '*********************************************************'