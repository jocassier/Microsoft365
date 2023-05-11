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
    $Workloads = (Get-ChildItem -Path '.\source\workloads' -Depth 1).BaseName
)
# purge build directory
if(Test-Path -Path '.\output')
{
    Remove-Item -Path '.\output' -Recurse -Force
}

Write-Output -InputObject 'Build Workload(s)...'

# Load configurations
$configurations = Get-ChildItem -Path '.\source\workloads' -Depth 1 -Filter '*.ps1' | Where-Object -FilterScript {$_.BaseName -in $ConfigurationName}

# Build configurations
$configurations | ForEach-Object {

    # Compile configuration
    . $_.FullName

    # execute configuration
    Invoke-Expression -Command "$($_.BaseName) -OutputPath .\output\workloads\$($_.BaseName)"
}

Write-Output -InputObject 'Build Local Configuration Manager...'

# Build LCM
$lcm = Get-ChildItem -Path '.\source\lcm\LCM.ps1'

# Compile lcm configuration
. $lcm.FullName

# execute lcm configuration
Invoke-Expression -Command "$($lcm.BaseName) -PartialConfiguration $($configurations.BaseName -join ',') -OutputPath .\output\lcm"