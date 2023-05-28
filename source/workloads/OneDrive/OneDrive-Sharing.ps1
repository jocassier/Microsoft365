configuration OneDrive-Sharing {

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'Microsoft365DSC'

    File OneDrive2
    {
        Contents = 'I Bins'
        DestinationPath = "C:\Users\Public\Documents\OneDrive.txt"
    }
}