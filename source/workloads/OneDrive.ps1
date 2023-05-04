configuration OneDrive {

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    File OneDrive
    {
        Contents = 'I Bins'
        DestinationPath = "C:\Users\Public\Documents\OneDrive.txt"
    }
}