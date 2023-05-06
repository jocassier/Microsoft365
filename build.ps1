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
    $ConfigurationName = (Get-ChildItem -Path '.\source\workloads').BaseName
)
# purge build directory
if(Test-Path -Path '.\output')
{
    Remove-Item -Path '.\output' -Recurse -Force
}


Write-Output -InputObject 'Build configurations...'

# Load configurations
$configurations = Get-ChildItem -Path '.\source\workloads' -Filter '*.ps1' | Where-Object -FilterScript {$_.BaseName -in $ConfigurationName}

# Build configurations
$configurations | ForEach-Object {

    # Compile configuration
    . $_.FullName

    # execute configuration
    (Invoke-Expression -Command "$($_.BaseName) -OutputPath .\output\workloads\$($_.BaseName)").Directory
}

# Build LCM
$lcm = Get-ChildItem -Path '.\source\LCM\LCM.ps1'

# Compile lcm configuration
. $lcm.FullName

# execute lcm configuration
(Invoke-Expression -Command "$($lcm.BaseName) -PartialConfiguration $($configurations.BaseName -join ',') -OutputPath .\output\$($lcm.BaseName)").Directory