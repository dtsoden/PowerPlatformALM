<#
.SYNOPSIS
Add AAD Application and SPN to the Power Platform AAD and configure The Power Platform to accept this SPN as tenant admin user.

.DESCRIPTION

The following Modules must be installed for this script to run properly
    1. AzureAD. To install run this command
         Install-Module -Name AzureAD -AllowClobber -Scope CurrentUser
    2. Microsoft.PowerApps.Administration.PowerShell. To install run this command
        Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -AllowClobber -Scope CurrentUser

-----------------------------------------------------------------------------------------------------------------------------------

This script assists in creating and configuring the ServicePrincipal to be used with
the Power Platform Build Command Line Interface (CLI) as well as the Power Platform Build Tools AzureDevOps task library.

Registers an Application object and corresponding ServicePrincipalName (SPN) with the Power Platform AAD instance.
This Application is then added as admin user to the Power Platform tenant itself.
NOTE: This script will prompt *TWICE* with the AAD login dialogs:
    1. time: to login as admin to the AAD instance associated with the Power Platform tenant
    2. time: to login as tenant admin to the Power Platform tenant itself

.PARAMETER DryRun    
DryRun = false (to set to true simply invoke the parameter with no value like -DryRun, do not use -DryRun $true or -DryRun true)

.PARAMETER AdminUrl
AdminUrl is programatically set base on the above TenantLocation - Do not set this unless you have specific reasons to do so.
            "UnitedStates"	            =	"https://admin.services.crm.dynamics.com"
            "Preview(UnitedStates)"	    =	"https://admin.services.crm9.dynamics.com"
            "Europe"		            =	"https://admin.services.crm4.dynamics.com"
            "EMEA"	                    =	"https://admin.services.crm4.dynamics.com"
            "Asia"	                    =	"https://admin.services.crm5.dynamics.com"
            "Australia"	                =	"https://admin.services.crm6.dynamics.com"
            "Japan"		                =	"https://admin.services.crm7.dynamics.com"
            "SouthAmerica"	            =	"https://admin.services.crm2.dynamics.com"
            "India"		                =	"https://admin.services.crm8.dynamics.com"
            "Canada"		            =	"https://admin.services.crm3.dynamics.com"
            "UnitedKingdom"	            =	"https://admin.services.crm11.dynamics.com"
            "France"		            =	"https://admin.services.crm12.dynamics.com"

.PARAMETER SecretExpiration
SecretExpiration = (New-TimeSpan -Days 365) 
    --> if you want it to last 2 years set to (New-TimeSpan -Days 730)
    --> if you want it to last 90 days set to (New-TimeSpan -Days 90)

.INPUTS
None

.OUTPUTS
Object with Power Platform TenantId, ApplicationId and client secret (in clear text);
use this triple to configure the Power Platform Build Command Line Interface (CLI) "PAC AUTH CREATE" command to create one or more 
authentication profiles, including the Power Platform Build Tools AzureDevOps task library ServiceConnections

.LINK
https://docs.microsoft.com/en-us/power-apps/developer/data-platform/powerapps-cli
https://marketplace.visualstudio.com/items?itemName=microsoft-IsvExpTools.PowerPlatform-BuildTools

.EXAMPLE
> New-PowerPlatform-ServicePrincipal
> New-PowerPlatform-ServicePrincipal -TenantLocation "Europe"
> New-PowerPlatform-ServicePrincipal -AdminUrl "https://admin.services.crm4.dynamics.com"
> New-PowerPlatform-ServicePrincipal -SecretExpiration (New-TimeSpan -Days 90)  # default is 365 days
#>
[CmdletBinding()]
Param(
    # gather permission requests but don't create any AppId nor ServicePrincipal
    [switch] $DryRun = $false,
    # other possible Azure environments, see: https://docs.microsoft.com/en-us/powershell/module/azuread/connect-azuread?view=azureadps-2.0#parameters
    [ValidateSet(
        "AzureCloud",
        "AzureChinaCloud",
        "AzureUSGovernment",
        "AzureGermanyCloud"
    )]
    [string] $AzureEnvironment = "AzureCloud",

    [ValidateSet(
        "UnitedStates",
        "Europe",
        "EMEA",
        "Asia",
        "Australia",
        "Japan",
        "SouthAmerica",
        "India",
        "Canada",
        "UnitedKingdom",
        "France"
    )]
    [string] $TenantLocation = "UnitedStates",
    [string] $AdminUrl,
    [TimeSpan] $SecretExpiration = (New-TimeSpan -Days 365)
)

$adminUrls = @{
    "UnitedStates"	            =	"https://admin.services.crm.dynamics.com"
    "Preview(UnitedStates)"	    =	"https://admin.services.crm9.dynamics.com"
    "Europe"		            =	"https://admin.services.crm4.dynamics.com"
    "EMEA"	                    =	"https://admin.services.crm4.dynamics.com"
    "Asia"	                    =	"https://admin.services.crm5.dynamics.com"
    "Australia"	                =	"https://admin.services.crm6.dynamics.com"
    "Japan"		                =	"https://admin.services.crm7.dynamics.com"
    "SouthAmerica"	            =	"https://admin.services.crm2.dynamics.com"
    "India"		                =	"https://admin.services.crm8.dynamics.com"
    "Canada"		            =	"https://admin.services.crm3.dynamics.com"
    "UnitedKingdom"	            =	"https://admin.services.crm11.dynamics.com"
    "France"		            =	"https://admin.services.crm12.dynamics.com"
    }

    function ensureModules {
    $dependencies = @(
        # the more general and modern "Az" a "AzureRM" do not have proper support to manage permissions
        @{ Name = "AzureAD"; Version = [Version]"2.0.2.137"; "InstallWith" = "Install-Module -Name AzureAD -AllowClobber -Scope CurrentUser" },
        @{ Name = "Microsoft.PowerApps.Administration.PowerShell"; Version = [Version]"2.0.131"; "InstallWith" = "Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -AllowClobber -Scope CurrentUser"}
    )
    $missingDependencies = $false
    $dependencies | ForEach-Object -Process {
        $moduleName = $_.Name
        $deps = (Get-Module -ListAvailable -Name $moduleName `
            | Sort-Object -Descending -Property Version)
        if ($deps -eq $null) {
            Write-Host @"
ERROR: Required module not installed; install from PowerShell prompt with:
>>  $($_.InstallWith) -MinimumVersion $($_.Version)
"@
            $missingDependencies = $true
            return
        }
        $dep = $deps[0]
        if ($dep.Version -lt $_.Version) {
            Write-Host @"
ERROR: Required module installed but does not meet minimal required version:
       found: $($dep.Version), required: >= $($_.Version); to fix, please run:
>>  Update-Module $($_.Name) -Scope CurrentUser -RequiredVersion $($_.Version)
"@
            $missingDependencies = $true
            return
        }
        Import-Module $moduleName -MinimumVersion $_.Version
    }
    if ($missingDependencies) {
        throw "Missing required dependencies!"
    }
}

function connectAAD {
    Write-Host @"

Connecting to AzureAD: Please log in, using your Dynamics365 / Power Platform tenant ADMIN credentials:

"@
    try {
        Connect-AzureAD -AzureEnvironmentName $AzureEnvironment -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Failed to login: $($_.Exception.Message)"
    }
    return Get-AzureADCurrentSessionInfo
}

function reconnectAAD {
    # for tenantID, see DirectoryID here: https://aad.portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/Overview
    try {
        $session = Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue
        if ($session.Environment.Name -ne $AzureEnvironment) {
            Disconnect-AzureAd
            $session = connectAAD
        }
    }
    catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
        $session = connectAAD
    }
    $tenantId = $session.TenantId
    Write-Host @"
Connected to AAD tenant: $($session.TenantDomain) ($($tenantId)) in $($session.Environment.Name)

"@
    return $tenantId
}

function addRequiredAccess {
    param(
        [System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]] $requestList,
        [Microsoft.Open.AzureAD.Model.ServicePrincipal[]] $spns,
        [string] $spnDisplayName,
        [string] $permissionName
    )
    Write-Host "  - requiredAccess for $spnDisplayName - $permissionName"
    $selectedSpns = $spns | Where-Object { $_.DisplayName -eq $spnDisplayName }

    # have to build the List<ResourceAccess> item by item since PS doesn't deal well with generic lists (which is the signature for .ResourceAccess)
    $selectedSpns | ForEach-Object -process {
        $spn = $_
        $accessList = New-Object -TypeName 'System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]'
        ( $spn.OAuth2Permissions `
        | Where-Object { $_.Value -eq $permissionName } `
        | ForEach-Object -process {
            $acc = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess'
            $acc.Id = $_.Id
            $acc.Type = "Scope"
            $accessList.Add($acc)
        } )
        Write-Verbose "accessList: $accessList"

        # TODO: filter out the now-obsoleted SPN for CDS user_impersonation: id = 9f7cb6a3-2591-431e-b80d-385fce1f93aa (PowerApps Runtime), see once granted admin consent in SPN permissions
        $req  = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.RequiredResourceAccess'
        $req.ResourceAppId = $spn.AppId
        $req.ResourceAccess = $accessList
        $requestList.Add($req)
    }
}

function calculateSecretKey {
    param (
        [int] $length = 32
    )
    $secret = [System.Byte[]]::new($length)
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider

    # restrict to printable alpha-numeric characters
    $validCharSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
    function getRandomChar {
        param (
            [uint32] $min = 0,
            [uint32] $max = $validCharSet.length - 1
        )
        $diff = $max - $min + 1
        [Byte[]] $bytes = 1..4
        $rng.getbytes($bytes)
        $number = [System.BitConverter]::ToUInt32(($bytes), 0)
        $index = [char] ($number % $diff + $min)
        return $validCharSet[$index]
    }
    for ($i = 0; $i -lt $length; $i++) {
        $secret[$i] = getRandomChar
    }
    return $secret
}

if ($PSVersionTable.PSEdition -ne "Desktop") {
    throw "This script must be run on PowerShell Desktop/Windows; the AzureAD module is not supported for PowershellCore yet!"
}
ensureModules
$ErrorActionPreference = "Stop"
$tenantId = reconnectAAD

$allSPN = Get-AzureADServicePrincipal -All $true

$requiredAccess = New-Object -TypeName 'System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]'

addRequiredAccess $requiredAccess $allSPN "Microsoft Graph" "User.Read"
addRequiredAccess $requiredAccess $allSPN "PowerApps-Advisor" "Analysis.All"
addRequiredAccess $requiredAccess $allSPN "Common Data Service" "user_impersonation"

$appBaseName = "POWERPLAT-SPN-$(get-date -Format "yyyyMMdd-HHmmss")"
$spnDisplayName = $appBaseName

Write-Verbose "Creating AAD Application: '$spnDisplayName'..."
$appId = "<dryrun-no-app-created>"
$spnId = "<dryrun-no-spn-created>"
if (!$DryRun) {
    # https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals
    $app = New-AzureADApplication -DisplayName $spnDisplayName -PublicClient $true -ReplyUrls "urn:ietf:wg:oauth:2.0:oob" -RequiredResourceAccess $requiredAccess
    $appId = $app.AppId
}
Write-Host "Created AAD Application: '$spnDisplayName' with appID $appId (objectId: $($app.ObjectId)"

$secretText = [System.Text.Encoding]::UTF8.GetString((calculateSecretKey))

Write-Verbose "Creating Service Principal Name (SPN): '$spnDisplayName'..."
$secretExpires = (get-date).Add($SecretExpiration)
if (!$DryRun) {
    # display name of SPN must be same as for the App itself
    # https://docs.microsoft.com/en-us/powershell/module/azuread/new-azureadserviceprincipal?view=azureadps-2.0
    $spn = New-AzureADServicePrincipal -AccountEnabled $true -AppId $appId -AppRoleAssignmentRequired $true -DisplayName $spnDisplayName -Tags {WindowsAzureActiveDirectoryIntegratedApp}
    $spnId = $spn.ObjectId

    $spnKey = New-AzureADServicePrincipalPasswordCredential -ObjectId $spn.ObjectId -StartDate (get-date).AddHours(-1) -EndDate $secretExpires -Value $secretText
    Set-AzureADServicePrincipal -ObjectId $spn.ObjectId -PasswordCredentials @($spnKey)
}
Write-Host "Created SPN '$spnDisplayName' with objectId: $spnId"

Write-Host @"

Connecting to Dynamics365 CRM managment API and adding appID to Dynamics365 tenant:
    Please log in, using your Dynamics365 / Power Platform tenant ADMIN credentials:
"@

if (!$DryRun) {
    if ($PSBoundParameters.ContainsKey("AdminUrl")) {
        $adminApi = $AdminUrl
    } else {
        $adminApi = $adminUrls[$TenantLocation]
    }
    Write-Host "Admin Api is: $adminApi"

    Add-PowerAppsAccount -Endpoint "prod"
    $mgmtApp = New-PowerAppManagementApp -ApplicationId $appId
    Write-Host @"

Added appId $($appId) to D365 tenant ($($tenantId))

"@
}
$result = [PSCustomObject] @{
    TenantId = $tenantId;
    ApplicationId = $appId;
    ClientSecret = $secretText;
    Expiration = $secretExpires;
}
Write-Output $result | Format-List