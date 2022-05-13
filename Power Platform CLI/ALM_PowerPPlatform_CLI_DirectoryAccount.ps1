<#
    
    Title:    ©2022 Microsoft - Partner Application Link, Power Platform CLI
    Platform: Windows PowerShell 5.1 *** DOES NOT SUPPORT POWERSHELL CORE ***
    Author:   David Soden
    Modified: 5/2/2022
    Dependency: Power Platform CLI 
    Download: https://aka.ms/PowerAppsCLI  

#>
[CmdletBinding()]
Param(
    # Set Variables
    [Parameter(Mandatory=$true, HelpMessage="Environment to export from...")]
        [String]$SourceEnvironment = "", 
    [Parameter(Mandatory=$true, HelpMessage="Environment to import into...")]
        [String]$DestinationEnvironment = "", 
    [Parameter(Mandatory=$true, HelpMessage="Name of the Solution to move across environments...")]
        [String]$Solution = "", 
    [Parameter(Mandatory=$true, HelpMessage="Solution Version-> Example 1.0.0.1")]
        [String]$OnlineVersion = "" 
)

#------------------------------------------------------------------------------------
# ALM with Power Platform CLI https://aka.ms/PowerAppsCLI
# -----------------------------------------------------------------------------------
# Create the credentials
#Clear-Host
pac auth clear
pac auth create -n Dev -u $SourceEnvironment
pac auth create -n Prod -u $DestinationEnvironment
# Run the ALM from DEV to PROD
#Clear-Host
pac auth select -i 1
pac solution online-version -sn $Solution -sv $OnlineVersion
pac solution export -m -n $Solution -p .\$Solution.zip
pac auth select -i 2
pac solution import -p .\$Solution.zip

#------------------------------------------------------------------------------------
# Take control over a canvas app - does not work on Model Driven Apps
#------------------------------------------------------------------------------------
## Take ownership of the Canvas App
#Add-PowerAppsAccount
#Set-AdminPowerAppOwner -AppName [[USER GUID]] -AppOwner $Global:currentSession.userId -EnvironmentName [[ENV GUID]]