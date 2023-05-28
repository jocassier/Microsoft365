configuration Teams {

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    File Teams3
    {
        Contents = 'I Bins'
        DestinationPath = "C:\Users\Public\Documents\Teams.txt"
    }
    
}