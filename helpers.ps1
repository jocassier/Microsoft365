function Resolve-Dependency {

    [CmdletBinding()]
    param (
       # Parameter help description
       [Parameter(Mandatory = $true)]
       [hashtable]
       $Dependencies,

       # Parameter help description
       [Parameter()]
       [hashtable]
       $UpdateM365DSC
    )
    
    
}