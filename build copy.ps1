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

#region Prepare

# purge build directory
if(Test-Path -Path '.\output')
{
    Remove-Item -Path '.\output' -Recurse -Force
}

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