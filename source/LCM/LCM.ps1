Configuration LCM
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = "ApplyOnly"
            CertificateId = $certForDSC.Thumbprint
        }
    }
}