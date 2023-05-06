configuration SharePoint {

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    File SharePoint
    {
        Contents = 'I Bins'
        DestinationPath = "C:\Users\Public\Documents\SharePoint.txt"
    }
    
}