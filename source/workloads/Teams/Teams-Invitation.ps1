configuration Teams-Invitation {

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    File Teams
    {
        Contents = 'I Bins'
        DestinationPath = "C:\Users\Public\Documents\Teams.txt"
    }
    
}