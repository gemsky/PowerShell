#Connect to Azure with Az.Account module

#Set Execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

#Variables
$AzSub = "G-subscription"
$tenantID = '6760843d-5916-443d-89fb-0e82f5f32289'

#auto connect  to azure
    #make sure module is installed:
    $AzAccountModule = Get-Module -ListAvailable Az.AzAccount
    if (!($AzAccountModule)) {
        #check if nuget is isntalled, else install it
        $NugetModule = Get-Module -ListAvailable Nuget
        if (!($NugetModule)) {
            Install-PackageProvider -Name NuGet -force      
        }

        #install az.Account module
        Install-Module -Name Az.Account -AllowClobber -Scope CurrentUser -Force
        Import-Module Az.Account
    }

    #Connect-AzAccount
    Connect-AzAccount -TenantId $tenantID
    Set-AzContext -Subscription $AzSub
