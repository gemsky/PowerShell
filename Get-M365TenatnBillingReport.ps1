<#
.SYNOPSIS
Extracts M365 license information from partner tenants, determines the partner relationship, and uploads the data to SharePoint for further processing by Power BI.

.DESCRIPTION
This script connects to partner tenants, retrieves M365 license information, determines the partner relationship, and saves the collected data into a CSV file. It then uploads the CSV files to SharePoint for further processing by Power BI.

.PARAMETER TenantList
Specifies the path to a CSV file containing a list of partner tenant names or IDs.

.PARAMETER OutputPath
Specifies the path where the output CSV files will be saved.

.PARAMETER SharePointURL
Specifies the URL of the SharePoint site where the CSV files will be uploaded.

.EXAMPLE
Save the script to your local repo amd run it from Terminal or PowerShell console.

.NOTES
- Ensure you have the required permissions and valid credentials to access the partner tenants and SharePoint site.
- The script requires the "AzureAD" and "MSOnline" PowerShell modules to be installed.
- Make sure the partner tenants are correctly listed in the TenantList.csv file.
- The CSV files will be uploaded to the default document library in the SharePoint site.
- Additional SharePoint-related functionalities, such as specifying a target document library or customizing metadata, can be added to the script as needed.
#>

#set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#Variables
$path = "$env:USERPROFILE\Billingreport\"
    #confirm path exist, else create
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path
    }

#functions - DO NOT EDIT OR INDENT
function Update-BillingCsv {
[CmdletBinding()]
param (
	[Parameter(Mandatory=$true,Position=0)]
	[string]
	$path
)
#Check if connected to msol 
if (!(Get-MsolUser -SearchString $env:USERNAME -ErrorAction SilentlyContinue)) {
	Write-Warning "Not connected to MSOL, connecting now!"
    Connect-MSOLService
} else {
	Write-Host "Connected to MSOL" -ForegroundColor Green
}

#Check and clean up file
$fPath = $path + "TenantBillingType.csv"
if (Test-Path $fPath) {
	Write-Warning "File already exists, deleting now!"
	Remove-Item $fPath
	Write-Host "File deleted" -ForegroundColor Green
} else {
	Write-Host "File does not exist" -ForegroundColor Green
}

# Get all of my customers in to a variable, the All is important or the results could be limited
	$AllCustomers = Get-MsolPartnerContract -All

#Loop through each customer
foreach ($Customer in $AllCustomers){
	Write-Progress -Activity "Checking Tenant" -Status "Checking $($Customer.Name)" -PercentComplete (($AllCustomers.IndexOf($Customer) / $AllCustomers.Count) * 100)
	$tenant = get-msolcompanyinformation -TenantId $Customer.TenantId -ErrorAction SilentlyContinue
	
	# Get the details of the license SKU you want to check
		try {
			$licenseSku = (Get-MsolAccountSku -TenantId  $Customer.tenantID -ErrorAction SilentlyContinue).AccountSkuId[0]
		}
		catch {
			#Catching Error if no license is assigned
		}
		# Check how the license was billed
		if ($licenseSku -like "*reseller*") {
			$licenseType = "ReSeller"
		} else {
			$licenseType = "PurchasedDirectly"
		}

	#Export results to CSV
	$results = [PSCustomObject]@{
		TenantName = $tenant.DisplayName
		InitialDomain = $tenant.InitialDomain
		TenantID = $Customer.TenantId
		LicenseType = $licenseType
	}
	$results | Export-Csv -Path $fPath -Append -NoTypeInformation
}
} #end of function

function Get-LicenseInfo {
	[CmdletBinding()]
	param (
		[Parameter()]
		[string]
		$path
	)
	
#Processing variables
$date = get-date -f yyyyMMdd
$CSV = $path + "$date.csv"
$Sku = @{
	"O365_BUSINESS_ESSENTIALS"			     = "Office 365 Business Essentials"
	"O365_BUSINESS_PREMIUM"				     = "Office 365 Business Premium"
	"DESKLESSPACK"						     = "Office 365 (Plan K1)"
	"DESKLESSWOFFPACK"					     = "Office 365 (Plan K2)"
	"LITEPACK"							     = "Office 365 (Plan P1)"
	"EXCHANGESTANDARD"					     = "Office 365 Exchange Online Only"
	"STANDARDPACK"						     = "Enterprise Plan E1"
	"STANDARDWOFFPACK"					     = "Office 365 (Plan E2)"
	"ENTERPRISEPACK"						 = "Enterprise Plan E3"
	"ENTERPRISEPACKLRG"					     = "Enterprise Plan E3"
	"ENTERPRISEWITHSCAL"					 = "Enterprise Plan E4"
	"STANDARDPACK_STUDENT"				     = "Office 365 (Plan A1) for Students"
	"STANDARDWOFFPACKPACK_STUDENT"		     = "Office 365 (Plan A2) for Students"
	"ENTERPRISEPACK_STUDENT"				 = "Office 365 (Plan A3) for Students"
	"ENTERPRISEWITHSCAL_STUDENT"			 = "Office 365 (Plan A4) for Students"
	"STANDARDPACK_FACULTY"				     = "Office 365 (Plan A1) for Faculty"
	"STANDARDWOFFPACKPACK_FACULTY"		     = "Office 365 (Plan A2) for Faculty"
	"ENTERPRISEPACK_FACULTY"				 = "Office 365 (Plan A3) for Faculty"
	"ENTERPRISEWITHSCAL_FACULTY"			 = "Office 365 (Plan A4) for Faculty"
	"ENTERPRISEPACK_B_PILOT"				 = "Office 365 (Enterprise Preview)"
	"STANDARD_B_PILOT"					     = "Office 365 (Small Business Preview)"
	"VISIOCLIENT"						     = "Visio Pro Online"
	"POWER_BI_ADDON"						 = "Office 365 Power BI Addon"
	"POWER_BI_INDIVIDUAL_USE"			     = "Power BI Individual User"
	"POWER_BI_STANDALONE"				     = "Power BI Stand Alone"
	"POWER_BI_STANDARD"					     = "Power-BI Standard"
	"PROJECTESSENTIALS"					     = "Project Lite"
	"PROJECTCLIENT"						     = "Project Professional"
	"PROJECTONLINE_PLAN_1"				     = "Project Online"
	"PROJECTONLINE_PLAN_2"				     = "Project Online and PRO"
	"ProjectPremium"						 = "Project Online Premium"
	"ECAL_SERVICES"						     = "ECAL"
	"EMS"								     = "Enterprise Mobility Suite"
	"RIGHTSMANAGEMENT_ADHOC"				 = "Windows Azure Rights Management"
	"MCOMEETADV"							 = "PSTN conferencing"
	"SHAREPOINTSTORAGE"					     = "SharePoint storage"
	"PLANNERSTANDALONE"					     = "Planner Standalone"
	"CRMIUR"								 = "CMRIUR"
	"BI_AZURE_P1"						     = "Power BI Reporting and Analytics"
	"INTUNE_A"							     = "Windows Intune Plan A"
	"PROJECTWORKMANAGEMENT"				     = "Office 365 Planner Preview"
	"ATP_ENTERPRISE"						 = "Exchange Online Advanced Threat Protection"
	"EQUIVIO_ANALYTICS"					     = "Office 365 Advanced eDiscovery"
	"AAD_BASIC"							     = "Azure Active Directory Basic"
	"RMS_S_ENTERPRISE"					     = "Azure Active Directory Rights Management"
	"AAD_PREMIUM"						     = "Azure Active Directory Premium"
	"MFA_PREMIUM"						     = "Azure Multi-Factor Authentication"
	"STANDARDPACK_GOV"					     = "Microsoft Office 365 (Plan G1) for Government"
	"STANDARDWOFFPACK_GOV"				     = "Microsoft Office 365 (Plan G2) for Government"
	"ENTERPRISEPACK_GOV"					 = "Microsoft Office 365 (Plan G3) for Government"
	"ENTERPRISEWITHSCAL_GOV"				 = "Microsoft Office 365 (Plan G4) for Government"
	"DESKLESSPACK_GOV"					     = "Microsoft Office 365 (Plan K1) for Government"
	"ESKLESSWOFFPACK_GOV"				     = "Microsoft Office 365 (Plan K2) for Government"
	"EXCHANGESTANDARD_GOV"				     = "Microsoft Office 365 Exchange Online (Plan 1) only for Government"
	"EXCHANGEENTERPRISE_GOV"				 = "Microsoft Office 365 Exchange Online (Plan 2) only for Government"
	"SHAREPOINTDESKLESS_GOV"				 = "SharePoint Online Kiosk"
	"EXCHANGE_S_DESKLESS_GOV"			     = "Exchange Kiosk"
	"RMS_S_ENTERPRISE_GOV"				     = "Windows Azure Active Directory Rights Management"
	"OFFICESUBSCRIPTION_GOV"				 = "Office ProPlus"
	"MCOSTANDARD_GOV"					     = "Lync Plan 2G"
	"SHAREPOINTWAC_GOV"					     = "Office Online for Government"
	"SHAREPOINTENTERPRISE_GOV"			     = "SharePoint Plan 2G"
	"EXCHANGE_S_ENTERPRISE_GOV"			     = "Exchange Plan 2G"
	"EXCHANGE_S_ARCHIVE_ADDON_GOV"		     = "Exchange Online Archiving"
	"EXCHANGE_S_DESKLESS"				     = "Exchange Online Kiosk"
	"SHAREPOINTDESKLESS"					 = "SharePoint Online Kiosk"
	"SHAREPOINTWAC"						     = "Office Online"
	"YAMMER_ENTERPRISE"					     = "Yammer for the Starship Enterprise"
	"EXCHANGE_L_STANDARD"				     = "Exchange Online (Plan 1)"
	"MCOLITE"							     = "Lync Online (Plan 1)"
	"SHAREPOINTLITE"						 = "SharePoint Online (Plan 1)"
	"OFFICE_PRO_PLUS_SUBSCRIPTION_SMBIZ"	 = "Office ProPlus"
	"EXCHANGE_S_STANDARD_MIDMARKET"		     = "Exchange Online (Plan 1)"
	"MCOSTANDARD_MIDMARKET"				     = "Lync Online (Plan 1)"
	"SHAREPOINTENTERPRISE_MIDMARKET"		 = "SharePoint Online (Plan 1)"
	"OFFICESUBSCRIPTION"					 = "Office ProPlus"
	"YAMMER_MIDSIZE"						 = "Yammer"
	"DYN365_ENTERPRISE_PLAN1"			     = "Dynamics 365 Customer Engagement Plan Enterprise Edition"
	"ENTERPRISEPREMIUM_NOPSTNCONF"		     = "Enterprise E5 (without Audio Conferencing)"
	"ENTERPRISEPREMIUM"					     = "Enterprise E5 (with Audio Conferencing)"
	"MCOSTANDARD"						     = "Skype for Business Online Standalone Plan 2"
	"PROJECT_MADEIRA_PREVIEW_IW_SKU"		 = "Dynamics 365 for Financials for IWs"
	"STANDARDWOFFPACK_IW_STUDENT"		     = "Office 365 Education for Students"
	"STANDARDWOFFPACK_IW_FACULTY"		     = "Office 365 Education for Faculty"
	"EOP_ENTERPRISE_FACULTY"				 = "Exchange Online Protection for Faculty"
	"EXCHANGESTANDARD_STUDENT"			     = "Exchange Online (Plan 1) for Students"
	"OFFICESUBSCRIPTION_STUDENT"			 = "Office ProPlus Student Benefit"
	"STANDARDWOFFPACK_FACULTY"			     = "Office 365 Education E1 for Faculty"
	"STANDARDWOFFPACK_STUDENT"			     = "Microsoft Office 365 (Plan A2) for Students"
	"DYN365_FINANCIALS_BUSINESS_SKU"		 = "Dynamics 365 for Financials Business Edition"
	"DYN365_FINANCIALS_TEAM_MEMBERS_SKU"	 = "Dynamics 365 for Team Members Business Edition"
	"FLOW_FREE"							     = "Microsoft Flow Free"
	"POWER_BI_PRO"						     = "Power BI Pro"
	"O365_BUSINESS"						     = "Office 365 Business"
	"DYN365_ENTERPRISE_SALES"			     = "Dynamics Office 365 Enterprise Sales"
	"RIGHTSMANAGEMENT"					     = "Rights Management"
	"PROJECTPROFESSIONAL"				     = "Project Professional"
	"VISIOONLINE_PLAN1"					     = "Visio Online Plan 1"
	"EXCHANGEENTERPRISE"					 = "Exchange Online Plan 2"
	"DYN365_ENTERPRISE_P1_IW"			     = "Dynamics 365 P1 Trial for Information Workers"
	"DYN365_ENTERPRISE_TEAM_MEMBERS"		 = "Dynamics 365 For Team Members Enterprise Edition"
	"CRMSTANDARD"						     = "Microsoft Dynamics CRM Online Professional"
	"EXCHANGEARCHIVE_ADDON"				     = "Exchange Online Archiving For Exchange Online"
	"EXCHANGEDESKLESS"					     = "Exchange Online Kiosk"
	"SPZA_IW"							     = "App Connect"
	"SPB"                                    = "Microsoft 365 Business Premium"
	"TEAMS_EXPLORATORY"                     = "Microsoft Teams Exploratory"
	"POWERAPPS_INDIVIDUAL_USER"             = "PowerApps and Logic Flows"
	"EMSPREMIUM"                            = "Microsoft Mobility + Security 365 E5"
	"ADALLOM_STANDALONE"                    = "Microsoft Cloud App Security"
	"POWERAPPS_VIRAL"                      = "Microsoft Power Apps Plan 2 Trial"
	"M365_F1_COMM"                       = "Microsoft 365 F1"
	"EXCHANGE_S_ESSENTIALS"              = "Exchange Online Essenstials"
	"PROJECT_PLAN1_DEPT"             = "Project Plan 1 (for Department)"
	"NONPROFIT_PORTAL"                 = "Nonprofit Portal"
	"SPE_E3"                         = "Microsoft 365 E3"
	"SPE_E5"                        = "Microsoft 365 E5"
	"TVM_Premium_Standalone"       = "Microsoft TVM standalone license"
	"TVM_Premium_Add_on"           = "Microsoft TVM add-on license"
	"Microsoft_Teams_Rooms_Pro" = "Microsoft Teams Rooms Pro Premium License"

}

#Get all clients
$clients = Get-MsolPartnerContract -All

#Loop through all clients
ForEach ($client in $clients)
{
	$ClientName = $client.Name
	Write-Progress "Working on $ClientName" 
	$Users = Get-MsolUser -TenantId $client.TenantId -maxresults 2000 | Where-Object { $_.isLicensed -eq "TRUE" } | Sort-Object DisplayName
	Foreach ($User in $Users)
	{
		Write-Progress "Working on $ClientName > $($User.DisplayName)..."
		#Gets users license and splits it at the semicolon
		Write-Progress "Getting all licenses for $($User.DisplayName)..."
		$Licenses = ((Get-MsolUser -TenantId $client.TenantId -UserPrincipalName $User.UserPrincipalName).Licenses).AccountSkuID
		If (($Licenses).Count -gt 1)
		{
			Foreach ($License in $Licenses)
			{
				Write-Progress "$ClientName > $($User.DisplayName) Finding $License in the Hash Table..."
				$LicenseItem = $License -split ":" | Select-Object -Last 1
				$TextLic = $Sku.Item("$LicenseItem")
				If (!($TextLic))
				{
					Write-Warning "Error: The Hash Table has no match for $LicenseItem for $($User.DisplayName)!"
					$LicenseFallBackName = $License.AccountSkuId
					$NewObject02 = $null
					$NewObject02 = @()
					$NewObject01 = New-Object PSObject
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "Name" -Value $User.DisplayName
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $User.UserPrincipalName
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "License" -Value "$LicenseFallBackName"
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "Tenant" -Value "$ClientName"
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "DataType" -Value "New"
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "Date" -Value "$date"
					$NewObject02 += $NewObject01
					$NewObject02 | Export-CSV $CSV -NoTypeInformation -Append
				}
				Else
				{
					$NewObject02 = $null
					$NewObject02 = @()
					$NewObject01 = New-Object PSObject
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "Name" -Value $User.DisplayName
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $User.UserPrincipalName
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "License" -Value "$TextLic"
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "Tenant" -Value "$ClientName"
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "DataType" -Value "New"
					$NewObject01 | Add-Member -MemberType NoteProperty -Name "Date" -Value "$date"
					$NewObject02 += $NewObject01
					$NewObject02 | Export-CSV $CSV -NoTypeInformation -Append
					
				}
			}
			
		}
		Else
		{
			Write-Progress "$ClientName > $($User.DisplayName) Finding $Licenses in the Hash Table..." 
			$LicenseItem = ((Get-MsolUser -TenantId $client.TenantId -UserPrincipalName $User.UserPrincipalName).Licenses).AccountSkuID -split ":" | Select-Object -Last 1
			$TextLic = $Sku.Item("$LicenseItem")
			If (!($TextLic))
			{
				Write-Warning "Error: The Hash Table has no match for $LicenseItem for $($User.DisplayName)!"
				$LicenseFallBackName = $License.AccountSkuId
				$LicenseFallBackName = $License.AccountSkuId
				$NewObject02 = $null
				$NewObject02 = @()
				$NewObject01 = New-Object PSObject
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "Name" -Value $User.DisplayName
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $User.UserPrincipalName
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "License" -Value "$LicenseFallBackName"
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "Tenant" -Value "$ClientName"
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "DataType" -Value "New"
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "Date" -Value "$date"
				$NewObject02 += $NewObject01
				$NewObject02 | Export-CSV $CSV -NoTypeInformation -Append
			}
			Else
			{
				$NewObject02 = $null
				$NewObject02 = @()
				$NewObject01 = New-Object PSObject
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "Name" -Value $User.DisplayName
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $User.UserPrincipalName
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "License" -Value "$TextLic"
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "Tenant" -Value "$ClientName"
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "DataType" -Value "New"
				$NewObject01 | Add-Member -MemberType NoteProperty -Name "Date" -Value "$date"
				$NewObject02 += $NewObject01
				$NewObject02 | Export-CSV $CSV -NoTypeInformation -Append
			}
		}
	}
}
Write-Host -ForegroundColor Green "Csv is saved to: $CSV"
} #end of function

function Update-SharePointRepo {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[string]
		$path,
        [Parameter(Mandatory=$True)]
        [string]
        $url,
        [Parameter(Mandatory=$True)]
        [string]
        $SharePointFolderPath
	)
# Connect to SharePoint Online
Connect-PnpOnline -Url $url -Interactive

# Define variables for the local file path and the SharePoint Online folder URL
$localFolderPath = $path 
$localFilePaths = (Get-ChildItem -Path $localFolderPath | Sort-Object LastWriteTime | Select-Object -Last 2).FullName
$folderUrl = $SharePointFolderPath 

#powershell pnp to upload file to sharepoint online
foreach ($localFilePath in $localFilePaths) {
	Write-Host "Uploading $localFilePath to $folderUrl"
	Add-PnPFile -Path $localFilePath -Folder $folderUrl
}
} #end of function

#Process
	#Part 1 - Update Billing Csv
	Update-BillingCsv -path $path

	#Part 2 - Extract this month License info from tenants
	Get-LicenseInfo -path $path

	#Part 3 - Update to SharePoint Online
    $spoParams = @{
        path = $path
        url = "https://contoso.sharepoint.com/sites/contoso" #your sharePoint site main page url
        $SharePointFolderPath = "/sites/Contoso/Shared Documents/" #your sharePoint folder path where you want the file to be uploaded to.
    }
	Update-SharePointRepo @spoParams
