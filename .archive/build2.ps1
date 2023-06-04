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

if(Test-Path -Path 'output')
{
    Remove-Item -Path 'output' -Recurse -Force   
}

$null = New-Item -Path 'output' -ItemType Directory

$configurations = @()

foreach($workload in $Workloads) 
{
    $configurations += Get-ChildItem -Path "source\workloads\$workload" -Filter '*.ps1' 
}

$result = New-Item -Path 'output\M365Configuration.ps1' -ItemType File

Add-Content -Path $result -Value "Configuration $($result.BaseName) {"

foreach($configuration in $configurations) 
{
    . $configuration.FullName
    $definition = (Get-Command -Name $configuration.BaseName -ShowCommandInfo -CommandType Configuration -Module '').Definition
    Add-Content -Path $result -Value $definition
}

Add-Content -Path $result -Value '}'

. $result.FullName

$null = Invoke-Expression -Command "$($result.BaseName) -OutputPath output"
