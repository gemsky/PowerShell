#set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#Chec if msol module is installed, else install it
if (Get-Module -ListAvailable -Name MSOnline) {
    Write-Host "MSOnline module confirmed installed" -ForegroundColor Green
} else {
    Write-Warning "MSOnline module is not installed, installing now!"
    Write-Progress -Activity "Installing MSOnline Module" -Status "Installing MSOnline Module"
    Install-Module -Name MSOnline -Force
    Write-Host "MSOnline module is installed" -ForegroundColor Green
}

#Check if connected to msol 
$test = Get-MsolUser -SearchString $env:USERNAME -ErrorAction SilentlyContinue
if ($test -eq $null) {
	Write-Warning "Not connected to MSOL, connecting now!"
    Write-Progress -Activity "Connecting to MSOL" -Status "Connecting to MSOL"
	Connect-MsolService
	Write-Host "Connected to MSOL" -ForegroundColor Green
} else {
	Write-Host "Connected to MSOL" -ForegroundColor Green
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
            $licenseType = "PartnerBilling"
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
    $path = "C:\temp\TenantsM365LicenseType.csv"
    $results | Export-Csv -Path $path -Append -NoTypeInformation
}

Write-Host "Script complete! Results can be found at $path." -f  Green