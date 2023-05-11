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

$workingDirectory = $PSScriptRoot
Set-Location -Path $workingDirectory

Write-Log -Message "Switching to path: $workingDirectory"
Write-Log -Message ' '
if (($env:PSModulePath -like "*$($workingDirectory)*") -eq $false)
{
    Write-Log -Message "Adding current folder to PSModulePath"
    $env:PSModulePath = $env:PSModulePath.TrimEnd(";") + "$([IO.Path]::PathSeparator)$($workingDirectory)"
}

Write-Log -Message 'Checking for presence of Microsoft365Dsc module and all required modules'
Write-Log -Message ' '

$modules = Import-PowerShellDataFile -Path (Join-Path -Path $workingDirectory -ChildPath 'DscResources.psd1')

if ($modules.ContainsKey("Microsoft365Dsc"))
{
    Write-Log -Message 'Checking Microsoft365Dsc version' -Level 1
    $psGalleryVersion = $modules.Microsoft365Dsc
    $localModule = Get-Module 'Microsoft365Dsc' -ListAvailable
    Write-Log -Message "Required version: $psGalleryVersion" -Level 2
    Write-Log -Message "Installed version: $($localModule.Version)" -Level 2

    if ($localModule.Version -ne $psGalleryVersion)
    {
        if ($null -ne $localModule)
        {
            Write-Log -Message 'Incorrect version installed. Removing current module.' -Level 3
            Write-Log -Message 'Removing Microsoft365DSC' -Level 4
            $m365ModulePath = Join-Path -Path 'C:\Program Files\WindowsPowerShell\Modules' -ChildPath 'Microsoft365DSC'
            Remove-Item -Path $m365ModulePath -Force -Recurse -ErrorAction 'SilentlyContinue'
        }

        Write-Log -Message 'Configuring PowerShell Gallery' -Level 4
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $psGetModule = Get-Module -Name PowerShellGet -ListAvailable | Select-Object -First 1
        if ($null -eq $psGetModule)
        {
            Write-Log -Message '* Installing PowerShellGet' -Level 5
            $null = Install-Module PowerShellGet -SkipPublisherCheck -Force
        }
        else
        {
            if ($psGetModule.Version -lt [System.Version]"2.2.4.0")
            {
                Write-Log -Message '* Installing PowerShellGet' -Level 5
                $null = Install-Module PowerShellGet -SkipPublisherCheck -Force
            }
        }

        Write-Log -Message 'Installing Microsoft365Dsc' -Level 4
        $null = Install-Module -Name 'Microsoft365Dsc' -RequiredVersion $psGalleryVersion
    }
    else
    {
        Write-Log -Message 'Correct version installed, continuing.' -Level 3
    }

    Write-Log -Message 'Modules installed successfully!'
    Write-Log -Message ' '
}
else
{
    Write-Log "[ERROR] Unable to find Microsoft365Dsc in DscResources.psd1. Cancelling!"
    Write-Error "Build failed!"
    Write-Host "##vso[task.complete result=Failed;]Failed"
    exit 10
}
<#
Write-Log -Message 'Preparing MOF compilation'
Write-Log -Message "Loading DSC configuration '$dscScriptName'" -Level 1
. (Join-Path -Path $workingDirectory -ChildPath $dscScriptName)

$outputFolder = Join-Path -Path $workingDirectory -ChildPath 'Output'
Write-Log -Message "Preparing OutputFolder '$outputFolder'" -Level 1
if ((Test-Path -Path $outputFolder))
{
    Remove-Item -Path $outputFolder -Recurse -Confirm:$false
}
$null = New-Item -Path $outputFolder -ItemType 'Directory'

Copy-Item -Path 'DscResources.psd1' -Destination $outputFolder
Copy-Item -Path 'deploy.ps1' -Destination $outputFolder
Copy-Item -Path 'checkdsccompliancy.ps1' -Destination $outputFolder

Write-Log -Message 'Retrieving Credentials' -Level 1
[array]$datafiles = Get-ChildItem -Path (Join-Path -Path $workingDirectory -ChildPath 'Datafiles') -Filter *.psd1
Write-Log -Message "Found $($datafiles.Count) data file(s)" -Level 2

$credentials = @{}
foreach ($datafile in $datafiles)
{
    Write-Log -Message "Processing: $($datafile.Name)" -Level 3

    $outputPathDataFile = Join-Path -Path $outputFolder -ChildPath $datafile.BaseName
    if ((Test-Path -Path $outputPathDataFile) -eq $false)
    {
        $null = New-Item -Path $outputPathDataFile -ItemType Directory
    }
    Copy-Item -Path $datafile.FullName -Destination $outputPathDataFile

    $envData = Import-PowerShellDataFile -Path $datafile.FullName
    $envName = $envData.NonNodeData.Environment.ShortName
    $credentials.$envName = @{}

    Write-Log -Message "Getting passwords from KeyVault '$VaultName'" -Level 4
    foreach ($function in $envData.NonNodeData.Accounts)
    {
        Write-Log -Message "Getting password from KeyVault for $($function.Workload)" -Level 4
        $keyVaultSearchString = "{0}-Cred-{1}" -f $envName, $function.Workload
        $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $keyVaultSearchString -ErrorAction SilentlyContinue
        if ($null -eq $secret)
        {
            Write-Log -Message "[ERROR] Cannot find $keyVaultSearchString in Azure KeyVault" -Level 5
            Write-Error "Build failed!"
            Write-Host "##vso[task.complete result=Failed;]Failed"
            exit 20
        }

        $password = $secret.SecretValue
        $username = $function.Account
        $cred = New-Object System.Management.Automation.PSCredential($username, $password)

        $credentials.$envName.$($function.Workload) = $cred
    }
}

Write-Log -Message ' '
Write-Log -Message 'Start MOF compilation'

foreach ($datafile in $datafiles)
{
    Write-Log -Message "Processing: $($datafile.Name)" -Level 2
    $envData = Import-PowerShellDataFile -Path $datafile.FullName
    $envName = $envData.NonNodeData.Environment.ShortName

    $certPath = Join-Path -Path $workingDirectory -ChildPath $envData.AllNodes[0].CertificateFile.TrimStart('.\')
    $envData.AllNodes[0].CertificateFile = $certPath
    $null = M365Configuration -Credentials $credentials.$envName -ConfigurationData $envData -OutputPath $outputFolder\$($datafile.BaseName)
}

Write-Log -Message ' '
Write-Log -Message '*********************************************************'
Write-Log -Message '*      Finished M365 DSC Configuration Compilation      *'
Write-Log -Message '*********************************************************'
Write-Log -Message ' '


#region Prepare

# purge build directory

#endregion

#region Build_configurations

Write-Output -InputObject 'Build configurations(s)...'

$configurations = @()

foreach($workload in $Workloads) 
{
    $configurations += Get-ChildItem -Path ".\source\workloads\$workload" -Filter '*.ps1' 
}

foreach($configuration in $configurations) 
{
    Write-Output -InputObject $configuration.BaseName

    # compile
    . $configuration.FullName

    # build
    $null = (Invoke-Expression -Command "$($configuration.BaseName) -OutputPath .\output\workloads\$($configuration.BaseName)")
}

#endregion

#region Build_lcm

$lcm = Get-ChildItem -Path '.\source\lcm\LCM.ps1'

Write-Output -InputObject $lcm.BaseName

# compile 
. $lcm.FullName

# build
$null = Invoke-Expression -Command "$($lcm.BaseName) -PartialConfiguration $($configurations.BaseName -join ',') -OutputPath .\output\lcm"

#endregion
#>