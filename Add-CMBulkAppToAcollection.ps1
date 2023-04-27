#Title: CM Add bulk apps To a Collection

#check CM module
    if ((Get-Module -Name "ConfigurationManager").Name) {
        
    } else {
        Write-Warning "No CCM module installed - improting!"
        Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
    }

    #check connection
    #Save current connection
    $curLoc = (Get-Location).Path

    #if no connected to CM Drive - Connect!
    if ((Get-Location).Path -eq "ADE:\") {
        Write-Host "Confirmed connection to CM Drive" -ForegroundColor Green
    } else {
        Write-Warning "Not connected to CM Drive - connecting..."
        
        #connect to CM Drive
        $SiteCode = Get-PSDrive -PSProvider CMSITE
            Set-Location -Path "$($SiteCode.Name):\"
    }


#Get App collections
    Write-Progress "Update Package Names to Text file"
    #Open Text file to enter hostnames
    $path = "C:\Temp\"
    $fileName = "AppList.txt"
    $filePath = $path+$fileName
    if (!(Test-Path $filePath)) {
        New-Item -Path $path -Name $fileName -ItemType "file"
    }
    C:\Temp\AppList.txt
    Write-Host "Enter 'Device Collections' names in to Notepad that just opened, then Save changes and close it for connection test to proceed"
    Write-Host "Make sure all open Notepads are closed, for process to proceed" -foregroundcolor Red

    #Get Notepad Process
    $nid = (Get-Process notepad).Id

    #Wait for Notepad to close
    Wait-Process -Id $nid

    #Add App Collection to variable
    $appList = Get-Content $filePath

    #Validate apps exist
    $goodApps = @()
    $badApps = @()
    Write-Progress "Validating apps..."
    foreach($app in $appList){
        $validateApp = Get-CMCollection -name $app
        if ($validateApp) {
            $goodApps += $app
        } else {
            $badApps += $app
        }
    }
    if (($badApps.count -gt 0) ) {
        Write-Host "============================" -ForegroundColor Yellow
        Write-Warning "These apps no longer exist:"
        Write-Host "============================" -ForegroundColor Yellow
        $badApps
        Write-Host "============================" -ForegroundColor Yellow
        Write-Host ""
    }
    

#Add PC to App collections
#Search app in CCM
Write-Progress "Searching app..."
$appkeyword = Read-Host "Enter Collection Name Keyword"
$CollectionName = (Get-CMCollection -name "*$appkeyword*" | Sort-Object -Property Name).Name | Out-GridView -PassThru

foreach ($app in $goodApps) {
    $gCD = (Get-CMDeployment -CollectionName $CollectionName | sort ApplicationName).ApplicationName
    if ($app -in $gCD) {
        Write-Warning " $app is already member of $CollectionName!"
    } else {
        try {
            Write-Progress "Adding $app to $CollectionName"
            New-CMApplicationDeployment -CollectionName $CollectionName -Name $app -DeployAction Install -DeployPurpose Required -UserNotification DisplaySoftwareCenterOnly -AvailableDateTime (Get-Date) -TimeBaseOn LocalTime | Out-Null
            Write-Host "Succesfully added $app to $CollectionName" -ForegroundColor Green    
        }
        catch {
            Write-Warning "Failed to add $app to $CollectionName!"
        }
        
    }
}


#End Script by returning to original drive location
#if connected to CM Drive - Reverse Connection!
if ((Get-Location).Path -eq "ADE:\") {
    Set-Location -path $curLoc   
}
