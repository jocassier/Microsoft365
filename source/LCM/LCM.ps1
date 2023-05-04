[DscLocalConfigurationManager()]
Configuration LCM
{

    [CmdletBinding()]
    param (
        [Parameter()]
        [System.String[]]
        $PartialConfiguration
    )

    Settings
    {
        ConfigurationMode = "ApplyOnly"
    }

    foreach($configuration in $PartialConfiguration) 
    {
        PartialConfiguration $configuration
        {
            RefreshMode = 'Push'
        }
    }
}