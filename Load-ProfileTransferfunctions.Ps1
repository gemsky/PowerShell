<#
.SYNOPSIS
Automates Windows profile transfers, simplifying the migration process and preserving user settings and preferences.

.DESCRIPTION
This powerful PowerShell script automates the transfer of Windows user profiles to a new device, making the migration process seamless and efficient. It intelligently detects common profile settings and preferences, ensuring that the user's personalized experience is preserved on the new device.

The script copies documents, common repositories, and other important files and folders from the source device to the destination device, ensuring that essential data is not lost during the migration. Additionally, it leverages the System Center Configuration Manager (SCCM) to detect deployed applications and automatically deploys them on the new device, ensuring that the user has all the necessary software readily available.

This automation saves significant time and effort during device migrations, providing a consistent and personalized user experience on the new device.

.EXAMPLE
Save and run script function as adminstartor:
Run-PreProfileDeployment

Once user creates profile, run the next function:
Run-PostProfileCreation

.NOTES
Part 1 - Pre deployment - no user interraction required. Both device needs to be online.
The first function: PreDeployment, does the following:
Validates the new device readiness for migration.
Validates the source device readiness for migration.
Collects app information to deploy to new device.
Adds user to local RDP group of the new deivce
Creates a RDP connection ICOn on user existing device to connect and create profile.

Part 2 - User login remotely to create profile - less than 5 minutes.
After the first function - guide user to login to new device via RDP.
Allow 5 minutes after first login for profile to consolidate on new device.

Part 3 - PostProfileCreation - no user interraction required. Both device needs to be online.
This script transfers user profile data, map drives, printer connectes, SCCM apps and lists manually installed apps.

Author: G Lim
Date: June 10, 2023
Version: 1.0

#>
function Run-PreProfileDeployment {
#Requirement
write-host "=======================Pre-Profile transfer Script====================="
write-host "Requirements:" -ForegroundColor yellow
write-host "Both New and old PC is currently Turned ON and connected to the Network" -ForegroundColor yellow
write-host "======================================================================="
    


#Get userName, New PC and Old PC name
    Write-progress "Get UserName and New PC Name"
    $username = Read-Host "Enter User's 5 character userID"

    $oldPc = Read-Host "Enter Old PC San number"
    Write-progress "Check Old computer is Online"
    if (Test-Connection -ComputerName $oldPc -Count 1 -quiet) {
        Write-Host "$oldPc is Online!" -ForegroundColor Green
    } else {
        Write-Warning "$oldPc is currently Offline Or unreachable - ending script!" 
        exit
    }

    $newPc = Read-Host "Enter new PC San number"
    Write-Progress "Get New PC Online status"
    if (Test-Connection -ComputerName $newPc -Count 1 -quiet) {
        Write-Host "$newPc is Online!"  -ForegroundColor Green
    } else {
        Write-Warning "$newPc is currently Offline Or unreachable - ending script!" 
        exit
    }

#Log Functions:
    #Log file Function to Display in host, progress bar and logs
    #check else Create file name
    $date = Get-date -Format ddMMyy
    $copyLog = "ProfileTransferLog"+$username+$date+".log"
    $logfilepath = "\\$newPc\C$\Temp\$CopyLog"

    function WriteHostDisplayAndLogFile ($message){
    Write-Host $message -ForegroundColor Yellow
    Write-Progress $message
    (Get-Date).ToString() + " " + $message  >> $logfilepath
    }

# Add user to new computer local RDP group
function Add-UserToLocalRdpGroup {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true,HelpMessage="Enter SAN number/Computer Name of the device")]
            [string]
            $computerName,
            [Parameter(Mandatory=$true,HelpMessage="Enter Users 'LastName, firtName' or what it starts with - to look up User Name")]
            [string]
            $username
        )
        Write-Progress "Computer info look up and confirm online status"
        #$computerName = Read-Host "Enter SAN number"
        if (Test-Connection -ComputerName $computerName -Count 1 -quiet) {
            Write-Progress "$computerName is Online!"
            
        } else {
            Write-Host "$computerName is currently Offline Or unreachable - ending script!" -ForegroundColor Red
            Exit
        }   
        
        Write-Progress "Get userID to add..."
        $SamAccountName = $null
        #Validate module: consoleGuiTools
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            if (!(Get-InstalledModule -name microsoft.powershell.ConsoleGuiTools)) {
            #Install GUI Tools
                Write-Progress "Installing Module"
                Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Force
                Import-Module -Name Microsoft.PowerShell.ConsoleGuiTools
            }  #Example: get-childitem | Out-ConsoleGridView
        
            #LookUp UserID PowerShell 7
            do {
                #prompt for Name input following 'lastName, FirstName' format
                #$username = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
                try {
                    $SamAccountName = (Get-ADUser $username).SamAccountName
                }
                catch {
                    #LookUp Relevant AD Account and display in consolegridview
                    $adObject = Get-ADUser -Filter "displayName -like '$username*'" |
                        Select-Object Name, SamAccountName |
                            Out-ConsoleGridView
        
                    #Specify UserID
                    $SamAccountName = $adObject.SamAccountName
                }
            } while ($SamAccountName -eq $null)
        } else {
            #LookUp UserID PowerShell 5.5
            do {
                #prompt for Name input following 'lastName, FirstName' format
                #$username = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
                try {
                    $SamAccountName = (Get-ADUser $username).SamAccountName
                }
                catch {
                    #LookUp Relevant AD Account and display in consolegridview
                    $adObject = Get-ADUser -Filter "displayName -like '$username*'" |
                        Select-Object Name, SamAccountName |
                            Out-GridView -PassThru
        
                    #Specify UserID
                    $SamAccountName = $adObject.SamAccountName
                }
            } while ($SamAccountName -eq $null)
        }
        write-host "Confirmed UserID is: $SamAccountName" -foregroundcolor green
        
        Invoke-Command -ComputerName $computerName -ScriptBlock { 
            Write-Progress "Validating Membership"
            $rdpUsers = Get-LocalGroupMember 'remote desktop users'
            if ($rdpUsers.Name -cmatch $using:SamAccountName){
                Write-Host "$using:SamAccountName is already member of $using:computerName 'remote desktop users' group"
            }else{
                Write-Progress "Confirmed user not member of group - Adding to local rdp group"
                try{
                    Add-LocalGroupMember 'remote desktop users' -Member $using:SamAccountName
                    Start-Sleep -Seconds 3
                    Write-Progress "Validating Membership"
                    $rdpUsers = Get-LocalGroupMember 'remote desktop users'
                    if ($rdpUsers.Name -cmatch $SamAccountName){
                        Write-Host "Successfully added $using:SamAccountName to $computerName Local RDP Group, to allow Remote access to the PC." -ForegroundColor Green
                    }else{
                        Write-Host "Unable to Confirm $using:SamAccountName is member of $computerName Local RDP Group." -ForegroundColor Red
                    } 
                }catch{
                    Write-Warning "Failed to add user to local rdp group"
                    throw
                }
            }
        } 

        #Codes Reff from here: https://adamtheautomator.com/invoke-command-remote/#:~:text=For%20Invoke%2DCommand%20to%20work,with%20the%20appropriate%20firewall%20exceptions.
} Add-UserToLocalRdpGroup -computerName $newPc -username $username

# New Device confirmation script
    Write-progress "This Script is to validate New build completion"
    Write-progress " Collecting data..."  

    #Create a custom object
    $stats = [ordered]@{
        MachineName = $newPc
        TotalMemmoryGB = 0
        AvailableMemoryGB = 0
        Winver = ""
        OSInstalDate = ""
        SystemDrive = ""
        SerialNumber = ""
        BiosVersion = ""
        BiosReleaseDate = ""
        BiosStatus = ""
        Timezone = ""
        SystemManufacturer = ""
        SystemModel = ""
        FreeDiskSpaceGB = ""
        DiskSizeGB = ""
        ADGroupMembership = ""
        DistinguishedName = ""
        }
    
    #Gather stats:
    Write-progress "Gather stats: app info" 
        #Memory Info
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $newPc |
            Select-Object TotalVirtualMemorySize,FreePhysicalMemory,SystemDrive
        
        #WindowsVersion, BiosSeralNumber, BiosSMBIOSBIOSVersion, BiosStatus, TimeZone
        $bios = Invoke-Command -ScriptBlock { 
            Get-ComputerInfo |
                Select-Object WindowsVersion,WindowsInstallDateFromRegistry,BiosSeralNumber,BiosSMBIOSBIOSVersion,BiosStatus,BiosReleaseDate,TimeZone,CsManufacturer,CsModel
        } -ComputerName $newPc
        
        #Hdd info
        $hdd = Invoke-Command -ScriptBlock { 
            Get-CimInstance -ClassName Win32_LogicalDisk | 
                Where-Object -property deviceID -eq "C:"
        } -ComputerName $newPc
        
        #Computer Membership
        $Adgm = Get-ADPrincipalGroupMembership (Get-ADComputer $newPc)

        #Ou Info
        $OUinfo = Get-ADComputer $newPc | Select-Object DistinguishedName

         

    #Load up customer object properties
    $stats.TotalMemmoryGB = [math]::Round(($os.TotalVirtualMemorySize / 1MB), 2)
    $stats.AvailableMemoryGB = [math]::Round(($os.FreePhysicalMemory / 1MB), 2)
    $stats.SystemDrive = $os.SystemDrive
    $stats.Winver = $bios.WindowsVersion
    $stats.OSInstalDate = $bios.WindowsInstallDateFromRegistry
    $stats.SerialNumber = $bios.BiosSeralNumber
    $stats.BiosVersion = $bios.BiosSMBIOSBIOSVersion
    $stats.BiosStatus = $bios.BiosStatus
    $stats.BiosReleaseDate = $bios.BiosReleaseDate
    $stats.Timezone = $bios.TimeZone
    $stats.SystemManufacturer = $bios.CsManufacturer
    $stats.SystemModel = $bios.CsModel
    $stats.DiskSizeGB = [math]::Round(($hdd.size /1GB), 2)
    $stats.FreeDiskSpaceGB = [math]::Round(($hdd.FreeSpace /1GB), 2)
    $stats.ADGroupMembership = $Adgm.Name
    $stats.DistinguishedName = $OUinfo.DistinguishedName

    $stats
    write-Host " "

    # Confirm SOE Applications Installed
    Write-progress "validating Core Apps installed" 
    write-Host "validate Core Apps installed:" -ForegroundColor Yellow
        Invoke-Command -ComputerName $newPc -ScriptBlock {   
            $coreApps = @('Adobe Acrobat Reader',
            'Airlock',
            'Citrix Workspace',
            'Configuration Manager Client',
            'CrowdStrike',
            'GlobalProtect',
            'Google Chrome',
            'Hive Streaming',
            'Ivanti',
            'Microsoft 365 Apps',
            'Microsoft OneDrive',
            'Microsoft Silverlight',
            'Teams',
            'TurboVNC',
            'VLC',
            'WalkMe')

        #32Bit apps from Registry list
        Write-Progress "32Bit apps "
        $32Bitapps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
            Select-Object -Property DisplayName |
                Sort-Object -Property DisplayName

        #64Bit apps from Registry list
        Write-Progress "64Bit apps " 
        $64Bitapps = Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
            Select-Object -Property DisplayName |
                Sort-Object -Property DisplayName

        #Merge List
        $allApps = $null
        $allApps = @($32Bitapps) + $64Bitapps

            foreach($coreApp in $coreApps){
                if ($allApps -match $coreApp) {
                    Write-Host "$coreApp installed" -ForegroundColor Green
                }else {
                    Write-Host "$coreApp NOT installed" -ForegroundColor Red
                }
            }
        }

    #Get Device manager - drivers status
    write-Host " "
    Write-Progress "Get Device manager driver status"
    $dmStatus = (Get-CimInstance Win32_PnPEntity -ComputerName $newPc | 
        Sort-Object -Property Name | 
            Where-Object {$_.Status -ne 'OK'}).Name

    if (!($dmStatus)) {
        Write-Host "Device Manager driver status: OK" -ForegroundColor Green    
    }

    if ($dmStatus -eq "PANGP Virtual Ethernet Adapter") {
        Write-Host "Device Manager driver status: OK" -ForegroundColor Green    
    } else {
        foreach ($driver in $dmStatus){
            Write-Warning "Error: $driver"
        }
    }
    write-Host " "

    #Validate timezone to WA
    Write-Progress "Validate timezone to WA"
    #Set timezone to W. Australia Standard Time
    Invoke-Command -ComputerName $newPc -ScriptBlock { 
        $tZone = Get-TimeZone
        if($tZone.id -ne "W. Australia Standard Time") {
            Write-Progress "Timzone incorrect - Adjusting"
            Set-TimeZone -id "W. Australia Standard Time"     
        }
        $timeZone = (Get-TimeZone).Id
        write-Host "Confirmed time-zone: $timeZone" -ForegroundColor Green
    }
    
    #triger CM action items remotely
    Write-Progress "Triger CM action items remotely"
    try {
        Invoke-Command -ComputerName $newPc -ScriptBlock {
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000121}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000003}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000010}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000002}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000031}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000111}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000032}"
        } | Out-Null
        Write-Host "Trigered Configuration manager Action item remotely." -ForegroundColor Green
    } catch {
        Write-Warning "Unable to triger CM action items remotely!!"
    }

    #triger GpUpdate
    Write-Progress "Triger GpUpdate remotely"
    try {
        Invoke-Command -ComputerName $newPc -ScriptBlock {
            gpupdate /force
        } -AsJob -JobName "$newPc" | Out-Null
        Write-Host "Trigered GpUpdate remotely." -ForegroundColor Green
    } catch {
        Write-Warning "Unable to triger GpUpdate remotely!!"
    }

    #Finish
    Write-Host "----Completed new build validation!---" -ForegroundColor Yellow

# Copy-CM Apps
#Get CCM app collection from Old PC and deploy to new Pc - AsJob
$func = {
    function GetCmAppNdeployToNewPc{
        [CmdletBinding()] 
        param (
            [Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$True,ValueFromPipeline=$True,
            HelpMessage="The Old computerName you would like to compare")] 
            [string]$oldPc,
    
            [Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$False,ValueFromPipeline=$True,
            HelpMessage="The New computerName that you would like to compare")] 
            [string]$newPc
        )
        Write-progress "Getting Unique CCM app collection and deploying to new PC"
        Write-Progress "Collecting data from $oldPc"
        $user1 = Invoke-Command -ComputerName $oldPc -ScriptBlock {
            (Get-CimInstance -ClassName CCM_Application -Namespace "root\ccm\clientSDK"  | 
                Sort-Object  name).Name
            }
        Write-Progress "Collecting data from $newPc"
        $user2 = Invoke-Command -ComputerName $newPc -ScriptBlock {
            (Get-CimInstance -ClassName CCM_Application -Namespace "root\ccm\clientSDK"  | 
                Sort-Object  name).Name
            }
        Write-Verbose ""
        Write-Verbose ($user2 -join "; ")
        $SameGroups = (Compare-Object $user1 $user2 -PassThru -IncludeEqual -ExcludeDifferent)
        Write-Verbose ""
        Write-Verbose ($SameGroups -join "; ")
        $UniqueID1 = (Compare-Object $user1 $user2 -PassThru | where {$_.SideIndicator -eq "<="})
        Write-Verbose ""
        Write-Verbose ($UniqueID1 -join "; ")
        $UniqueID2 = (Compare-Object $user1 $user2 -PassThru | where {$_.SideIndicator -eq "=>"})
        Write-Verbose ""
        Write-Verbose ($UniqueID2 -join "; ")
        Write-Host "----------------------------------------------"
        Write-Host "Deploying these App collections to New device:" -ForegroundColor Green
        Write-Host "----------------------------------------------"
        $UniqueID1
        Write-Host ""
        
        #check CM module
        if ((Get-Module -Name "ConfigurationManager").Name) {
            
        } else {
            Write-Progress "No CCM module installed - improting!"
            Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
        }
    
        #check connection
        #Save current connection
        $curLoc = (Get-Location).Path
    
        #if no connected to CM Drive - Connect!
        if ((Get-Location).Path -eq "ADE:\") {
            Write-Host "Confirmed connection to CM Drive" -ForegroundColor Green
        } else {
            Write-Progress "connecting to CM Drive..."
            
            #connect to CM Drive
            $SiteCode = Get-PSDrive -PSProvider CMSITE
                Set-Location -Path "$($SiteCode.Name):\"
        }
    
        #Get PC Name
        $ComputerName = $newPc
        #Add App Collection to variable
        $appList = $UniqueID1
    
        #Validate apps exist
        $goodApps = @()
        $badApps = @()
    
        foreach($app in $appList){
            Write-Progress "Validating $app - if collection exist"
            $validateApp = Get-CMCollection -name $app
            if ($validateApp) {
                $goodApps += $app
            } else {
                $badApps += $app
            }
        }
        if (($badApps.count -gt 0) ) {
            Write-Host ""
            Write-Host "============================" -ForegroundColor Yellow
            Write-host "These apps no longer exist:" -ForegroundColor Red
            Write-Host "============================" -ForegroundColor Yellow
            $badApps 
            Write-Host "============================" -ForegroundColor Yellow
            Write-Host ""
        }
    
        #Add PC to App collections
        foreach ($app in $goodApps) {
            $gCCM = (Get-CMCollectionMember -collectionName $app).Name
            if ($ComputerName -in  $gCCM) {
                Write-Host "$ComputerName is already member of $app collection!" -ForegroundColor Yellow
            } else {
                try {
                    Write-Progress "Adding $ComputerName to $app"
                    Add-CMDeviceCollectionDirectMembershipRule -CollectionName $app -resourceID (get-cmdevice -Name $ComputerName).ResourceID
                }
                catch {
                    Write-Warning "Failed to add $ComputerName to $app collection"
                }                
            }
        }
    
        write-progress "Run CCM action items on client - Requires computer to be online"
        Write-Progress "Trigering CM Action items remotely "
        get-job | remove-job
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000121}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000003}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000010}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000002}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000031}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000111}"
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000032}"
        } -JobName $ComputerName -AsJob  | Out-Null
    
        $cmActionItemsStat = (Get-Job -Name $ComputerName).state
        Write-Host "$cmActionItemsStat CCM Action items remotely!" -ForegroundColor Green
    
        #End Script by returning to original drive location
        #if connected to CM Drive - Reverse Connection!
        if ((Get-Location).Path -eq "ADE:\") {
            Set-Location -path $curLoc   
        }
    }
}
Start-Job  -name "GetCmAppNdeployToNewPc" -scriptblock{
    param($oldPc,$newPc) GetCmAppNdeployToNewPc $oldPc $newPc
} -InitializationScript $func -ArgumentList ($oldPc,$newPc) | Out-Null
    
#Compare-InstalledApps
$func = {
    function CompareInstalledApps{
        param([string]$oldPc,[string]$newPc)
        Write-Progress "Compare-InstalledApps"
        #Apps from Registry list
        $apps1 = Invoke-Command -ComputerName $newPc -ScriptBlock {
            #32Bit apps from Registry list
            $32bit = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*").DisplayName
        
            #64Bit apps from Registry list
            $64bit = (Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*").DisplayName
            
            #Merge List
            $32bit + $64bit
        }
        
        $apps2 = Invoke-Command -ComputerName $oldPc -ScriptBlock {
            #32Bit apps from Registry list
            $32bit = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*").DisplayName
        
            #64Bit apps from Registry list
            $64bit = (Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*").DisplayName
            
            #Merge List
            $32bit + $64bit
        } 
        
        #List of core apps - add here as we go
        $coreApps = "64 Bit HP CIO Components Installer
        Access Panel Extension
        Adobe Acrobat DC
        Adobe Acrobat Reader DC
        Adobe Refresh Manager
        Airlock Digital Client
        Asmedia USB Host Controller Driver
        Autodesk Advanced Material Library Image Library 2018
        Autodesk Material Library Base Resolution Image Library 2018
        Cisco Jabber
        Citrix Authentication Manager
        Citrix Screen Casting for Windows
        Citrix Web Helper
        Citrix Workspace 2006
        Citrix Workspace 2009
        Citrix Workspace 2202
        Citrix WorkSpace Browser
        Citrix Workspace Inside
        Citrix Workspace(DV)
        Citrix Workspace(SSON)
        Citrix Workspace(USB)
        Client Applications
        Configuration Manager Client
        Content Web Server Extension
        CrowdStrike Device Control
        CrowdStrike Firmware Analysis
        CrowdStrike Sensor Platform
        CrowdStrike Windows Sensor
        DefaultPackMSI
        Dell Command | Update for Windows 10
        Dell PointStick Driver
        Dell SupportAssist OS Recovery Plugin for Dell Update
        DisplayLink Graphics Driver
        Dolby Audio X2 Windows API SDK
        GlobalProtect
        GLSU
        Google Chrome
        Google Update HelperTurboVNC 64-bit v2.1.1 (20170202)
        Hive Streaming
        HP Customer Experience Enhancements
        HP Support Assistant
        HP Support Solutions Framework
        HP Thunderbolt Dock G2 Firmware Installer
        Intel Software Package
        Intel(R) 2D Imaging
        Intel(R) 2D Imaging Setup Wizard
        Intel(R) Dynamic Platform and Thermal Framework
        Intel(R) Dynamic Tuning
        Intel(R) Dynamic Tuning Technology
        Intel(R) HID Event Filter
        Intel(R) Management Engine Components
        Intel(R) Management Engine Driver
        Intel(R) Processor Graphics
        Intel(R) Rapid Storage Technology
        Intel(R) Serial IO
        Intel(R) Trusted Connect Service Client x64
        Intel(R) Trusted Connect Service Client x86
        Intel(R) Trusted Connect Services Client
        Intel(R) Virtual Buttons
        Intel(R) Wireless Bluetooth(R)
        Intel Optane Pinning Explorer Extensions
        Intel Software Installer
        Ivanti Application Control Agent 2019.1
        Ivanti Deployment Agent (CCA) 10.1 (FR1)
        Ivanti Environment Manager Agent 2019.1
        Ivanti Windows Configuration - AM Policy 2019.1
        Ivanti Windows Configuration - EM Policy 2019.1
        Java 7 Update 67
        Local Administrator Password Solution
        Logitech Unifying Software 2.50
        Maxx Audio Installer (x64)
        Microsoft .NET Framework 1.1
        Microsoft 365 Apps for enterprise - en-us
        Microsoft Advanced Group Policy Management - Client
        Microsoft Corporation
        Microsoft DirectAccess Connectivity Assistant
        Microsoft Edge
        Microsoft Edge Update
        Microsoft Edge WebView2 Runtime
        Microsoft Endpoint Configuration Manager Console
        Microsoft OneDrive
        Microsoft Policy Platform
        Microsoft Project - en-us
        Microsoft ReportViewer 2010 SP1 Redistributable (KB2549864)
        Microsoft Search in Bing
        Microsoft Silverlight
        Microsoft SQL Server 2012 Native Client
        Microsoft SQL Server 2014 Management Objects  (x64)
        Microsoft SQL Server 2016 LocalDB
        Microsoft System CLR Types for SQL Server 2014
        Microsoft Unified Communications Managed API 5.0, Core Runtime 64-bit
        Microsoft Update Health Tools
        Microsoft VC++ redistributables repacked.
        Microsoft Visio - en-us
        Microsoft Visio Viewer 2013
        Microsoft Visio Viewer 2016
        Microsoft Visual C++ 2005 Redistributable
        Microsoft Visual C++ 2005 Redistributable (x64)
        Microsoft Visual C++ 2008 Redistributable - x64 9.0.30729.17
        Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.17
        Microsoft Visual C++ 2010  x64 Redistributable - 10.0.40219
        Microsoft Visual C++ 2010  x86 Redistributable - 10.0.40219
        Microsoft Visual C++ 2012 Redistributable (x86) - 11.0.61030
        Microsoft Visual C++ 2012 x86 Additional Runtime - 11.0.60610
        Microsoft Visual C++ 2012 x86 Additional Runtime - 11.0.61030
        Microsoft Visual C++ 2012 x86 Minimum Runtime - 11.0.60610
        Microsoft Visual C++ 2012 x86 Minimum Runtime - 11.0.61030
        Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.21005
        Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.30501
        Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.40660
        Microsoft Visual C++ 2013 Redistributable (x86) - 12.0.21005
        Microsoft Visual C++ 2013 Redistributable (x86) - 12.0.30501
        Microsoft Visual C++ 2013 Redistributable (x86) - 12.0.40660
        Microsoft Visual C++ 2013 x64 Additional Runtime - 12.0.40660
        Microsoft Visual C++ 2013 x64 Minimum Runtime - 12.0.40660
        Microsoft Visual C++ 2013 x86 Additional Runtime - 12.0.40660
        Microsoft Visual C++ 2013 x86 Minimum Runtime - 12.0.40660
        Microsoft Visual C++ 2015-2019 Redistributable (x64) - 14.29.30135
        Microsoft Visual C++ 2015-2019 Redistributable (x64) - 14.29.30139
        Microsoft Visual C++ 2015-2019 Redistributable (x86) - 14.29.30135
        Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.30.30704
        Microsoft Visual C++ 2015-2022 Redistributable (x86) - 14.30.30704
        Microsoft Visual C++ 2019 X64 Additional Runtime - 14.29.30135
        Microsoft Visual C++ 2019 X64 Minimum Runtime - 14.29.30135
        Microsoft Visual C++ 2019 X86 Additional Runtime - 14.29.30135
        Microsoft Visual C++ 2019 X86 Minimum Runtime - 14.29.30135
        Microsoft Visual C++ 2022 X64 Additional Runtime - 14.30.30704
        Microsoft Visual C++ 2022 X64 Minimum Runtime - 14.30.30704
        Microsoft Visual C++ 2022 X86 Additional Runtime - 14.30.30704
        Microsoft Visual C++ 2022 X86 Minimum Runtime - 14.30.30704
        Microsoft Visual Studio 2010 Tools for Office Runtime (x64)
        Microsoft Visual Studio Code
        Mimecast for Outlook 32-bit
        Mimecast for Outlook 64-bit
        MSXML 4.0 SP3 Parser
        Office 16 Click-to-Run Extensibility Component
        Office 16 Click-to-Run Extensibility Component 64-bit Registration
        Office 16 Click-to-Run Licensing Component
        Office 16 Click-to-Run Localization Component
        Online Plug-in
        Oracle TNS LDAP Fix
        Password Policy Client 9.11
        Procon Document Control
        Production Control Center 250 Client
        Realtek Audio COM Components
        Realtek Audio Driver
        Realtek Card Reader
        Realtek High Definition Audio Driver
        Realtek USB Audio
        Realtek USB Ethernet Controller All-In-One Windows Driver
        Self-service Plug-in
        Teams Machine-Wide Installer
        ThinkPad Thunderbolt 3 Dock and USB-C Dock
        ThinkPad USB-C Dock USB Audio
        Thunderbolt Software
        VLC media player 3.0.16 (64-bit)
        WalkMe Internet Explorer ATL Extension
        WalkMe Workstation"
        
        $user1 = @()
        #Clean up array from Ms, Drivers and core apps
        foreach($app in $apps1){
            $va = ($coreApps).contains($app)  
            if (!($va)) {
                $user1 += $app
            }
        }
        
        $user2 = @()
        #Clean up array from Ms, Drivers and core apps
        foreach($app in $apps2){
            $va = ($coreApps).contains($app)  
            if (!($va)) {
                $user2 += $app
            }
        }
        
        #To make array work with Compare-Object user this:    @($user1 | Select-Object)
        $SameGroups = (Compare-Object @($user1 | Select-Object) @($user2 | Select-Object) -PassThru -IncludeEqual -ExcludeDifferent)
        $UniqueID1 = (Compare-Object @($user1 | Select-Object) @($user2 | Select-Object) -PassThru | where {$_.SideIndicator -eq "<="})
        $UniqueID2 = (Compare-Object @($user1 | Select-Object) @($user2 | Select-Object) -PassThru | where {$_.SideIndicator -eq "=>"})
        $ID1Name = $newPc
        $ID2Name = $oldPc
    
        Write-Host ""
        Write-Host "----------------------------------------------------------------"
        Write-Host "These Apps may neeed to be added manually to New Device [$ID1Name]:" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------"
        $UniqueID2 | Sort-Object -CaseSensitive
    } 
}
Start-Job  -name "CompareInstalledApps" -scriptblock{
    param($oldPc,$newPc) CompareInstalledApps $oldPc $newPc
} -InitializationScript $func -ArgumentList ($oldPc,$newPc) | Out-Null    
    
#Copy Script to user old desktop for user to triger:
    # Copy batch file and update script with new PC name, includes: Mstsc -v $newPC and Copy Mapped Drivers
    write-progress "Create directory info"
        $from = "\\perall02\apps\EUC\SignedScripts\NewPcLogin.bat"
        $Destination = "\\$oldPc\C$\Temp\"
        $desktopScriptPath = "\\perall02\apps\EUC\SignedScripts\ConnectToNewPC.lnk"
        $desktopScriptDestionation = "\\$oldPc\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\Windows System"

    write-progress "Copying - NewPcLogin.bat to user desktop..."
    try {
        Copy-item -Path $from -Destination $Destination -Force
        WriteHostDisplayAndLogFile "Successfully transfered: NewPcLogin.bat to $Destination"
    } catch {
        WriteHostDisplayAndLogFile $_.Exception.Message
    }
    
    write-progress "Copying - ConnectToNewPC.lnk to user StartMenu..."
    try {
        Copy-item -Force -path $desktopScriptPath -destination $desktopScriptDestionation
        WriteHostDisplayAndLogFile "Successfully transfered: ConnectToNewPC.lnk to user StartMenu"
    } catch {
        WriteHostDisplayAndLogFile $_.Exception.Message
    }
     
        
    write-progress "Update Batchfile content..."
        $scriptOnOldPc = "\\$oldPc\C$\Temp\NewPcLogin.bat"    
        try {
            $newText = "mstsc -v $newPc"
            $content = Get-Content $scriptOnOldPc
            $content[2] = $newText
            $content | Set-Content $scriptOnOldPc
            WriteHostDisplayAndLogFile "Successfully updated: NewPcLogin.bat with $newText"
        } catch {
            WriteHostDisplayAndLogFile $_.Exception.Message
        }

#AutoConnect Follow-You Print
    $from = "\\perall02\apps\EUC\SignedScripts\AutoConnect - Follow-You Print.lnk"
    $Destination = "\\$newPc\C$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"

    Write-Progress "Copy AutoConnect Follow-You Print to $newPc StartUp folder"
    try {
        Copy-item -Path $from -Destination $Destination -Force
        WriteHostDisplayAndLogFile "Successfully transfered: 'AutoConnect Follow-You Print' script to $newPc StartUp folder"
    } catch {
        WriteHostDisplayAndLogFile $_.Exception.Message
    }

#Copy EUC script folder to newPC Start Menu
    $path = "\\perall02\apps\EUC\SignedScripts\EUC"
    $destination = "\\$newPc\C$\ProgramData\Microsoft\Windows\Start Menu\Programs\"

    try {
        Write-Progress "Copying EUC script folder to: $newPc"
        Copy-Item -Path $path -Destination $destination -Recurse -Force    
        WriteHostDisplayAndLogFile "Succesfully copied 'EUC' script folder to: $newPc"
    }
    catch {
        WriteHostDisplayAndLogFile $_.Exception.Message
    }

Receive-Job -name "CompareInstalledApps" -Wait
Receive-Job -name "GetCmAppNdeployToNewPc" -Wait
get-job | Stop-Job
get-job | remove-job

write-Host "---Completed New device validation and profile Apps transfer!---" -ForegroundColor yellow
} #end of PreDeployment function

function Run-PostProfileCreation {
    #Requirement
write-host "=====================Profile data transfer Script=========================="
write-host "Requirements:" -ForegroundColor yellow
write-host "1. Make sure new user profile has been created on the new PC" -ForegroundColor yellow
write-host "2. Both New and old PC is currently Turned ON and connected to the Network" -ForegroundColor yellow
write-host "==========================================================================="

#Functions:
    #Log file Function to Display in host, progress bar and logs
    #check else Create file name
    $date = Get-date -Format ddMMyy
    $copyLog = "ProfileTransferLog"+$username+$date+".log"
    $logfilepath = "C:\Temp\$CopyLog"

    function WriteHostDisplayAndLogFile ($message){
    Write-Host $message -ForegroundColor Yellow
    Write-Progress $message
    (Get-Date).ToString() + " " + $message  >> $logfilepath
    }

Write-progress "Get UserName and New PC Name"
    $username = Read-Host "Enter User's 5 character userID"
    
    $oldPc = Read-Host "Enter Old PC San number"
    Write-progress "Check Old computer is Online"
    if (Test-Connection -ComputerName $oldPc -Count 1 -quiet) {
        WriteHostDisplayAndLogFile "$oldPc is Online!"
    } else {
        WriteHostDisplayAndLogFile "$oldPc is currently Offline Or unreachable - ending script!" 
        exit
    }
    
    $newPc = Read-Host "Enter new PC San number"
    Write-Progress "Get New PC Online status"
    if (Test-Connection -ComputerName $newPc -Count 1 -quiet) {
        WriteHostDisplayAndLogFile "$newPc is Online!"
    } else {
        WriteHostDisplayAndLogFile "$newPc is currently Offline Or unreachable - ending script!" 
        exit
    }
    
    Write-Progress "Check  New computer profile is created"
    $profileFolder = "\\$newPc\c$\Users\$username"
    $profileFolderCheck = Test-Path -Path $profileFolder
    if ($profileFolderCheck) {
        WriteHostDisplayAndLogFile "User profile on $newPc Confirmed!"
        Write-Progress "Requirements confirmed, proceeding with profile transfer." 
    } else {
        WriteHostDisplayAndLogFile "NO User profile on $newPc - Ending script!" 
        WriteHostDisplayAndLogFile "Ask user to login to $newPc first to create user profile!" 
        exit
    }

    Write-Host ""

Write-Progress "Starting Transfer: C drive Content"
    #Calculate folder size
    $folders = @("Desktop","Documents","Pictures")
        foreach ($folder in $folders) {
            Write-Progress "Calculating $folder folder size"
            #Create directory info for current and new profile folder: Variable
            $folderPath = "\\$oldPc\c$\Users\$username\$folder"
            if (Test-Path $folderPath) {
                $foldersizeMB = "{0:N2} MB" -f ((Get-ChildItem -Force $folderPath -Recurse -ErrorAction SilentlyContinue| Measure-Object Length -Sum ).sum / 1MB)
                $foldersizeGB = "{0:N2} GB" -f ((Get-ChildItem -Force $folderPath -Recurse -ErrorAction SilentlyContinue| Measure-Object Length -Sum ).sum / 1GB)
                WriteHostDisplayAndLogFile "$folder size is $foldersizeMB OR $foldersizeGB" -ForegroundColor Green
            } else {
                WriteHostDisplayAndLogFile "$folder folder is now Manged and backed up in OneDrive - no data transfer required"
            }   
        }
            
    Write-Progress "Transfer UserProfile Content: Documents"
        #Create directory info for current and new profile folder: Documents
        $from = "\\" + $oldPc + "\c$\Users\" + $username + "\Documents\*"
        $Destination = "\\" + $newPc + "\c$\Users\" + $username + "\Documents"
        Write-Progress "Copying Documents folder"
        try{ 
            Copy-item -Force -Recurse $from $Destination -Exclude @("My Music","My Pictures","My Videos") -ErrorAction SilentlyContinue
            WriteHostDisplayAndLogFile "Successfully transfered: Documents"
        } catch {
            WriteHostDisplayAndLogFile $_.Exception.Message 
        }

    Write-Progress "Transfer The rest of UserProfile folders"
        $folders = @("Desktop","Pictures","Favorites","Favourites")
        foreach ($folder in $folders) {
            #Create directory info for current and new profile folder: Variable
            $from = "\\" + $oldPc + "\c$\Users\" + $username + "\" + $folder + "\*"
            $Destination = "\\" + $newPc + "\c$\Users\" + $username + "\" + $folder
            Write-Progress "Copying $folder folder" 
            try{                
                Copy-item -Force -Recurse $from $Destination -ErrorAction SilentlyContinue
                WriteHostDisplayAndLogFile "Successfully transfered: $folder"
            } catch {
                WriteHostDisplayAndLogFile $_.Exception.Message 
            }
        }
            
    Write-Progress "Transfer Favourites - Chrome"
    #Create directory info for current and new profile folder: Documents
        $from = "\\" + $oldPc + "\c$\Users\" + $username + "\appdata\local\Google\Chrome\User Data\Default\Bookmarks"
        $Destination = "\\" + $newPc + "\c$\Users\" + $username + "\appdata\local\Google\Chrome\User Data\Default"
    
    #confirm directory path
        if (!(Test-path -path $Destination)) {
            new-item -path $Destination -itemtype "Directory" | Out-Null
        }
    
    Write-progress "Copying Chrome Bookmark..." 
    try{        
        Copy-item -Force -Recurse $from $Destination
        WriteHostDisplayAndLogFile "Successfully transfered: Chrome bookmarks"
    } catch {
        WriteHostDisplayAndLogFile $_.Exception.Message 
    }

Write-Progress "Favourites - Edge - Roaming profile turned on - OR it was copied from Chrome - No Action required"

Write-Progress "Transfering QuickAccess..."
    #Create directory info
    $from = "\\$oldPc\C$\Users\$username\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations" + "\*"
    $Destination = "\\$newPc\C$\Users\$username\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations"
   
    #confirm directory path
    if (!(Test-path -path $Destination)) {
        new-item -path $Destination -itemtype "Directory"
    }
    Write-progress "Copying QuickAccess: automaticDestinations" 
    try{
        Copy-item -Force -Recurse -path $from -destination $Destination
        WriteHostDisplayAndLogFile "Successfully transfered QuickAccess: automaticDestinations"
    } catch {
        WriteHostDisplayAndLogFile $_.Exception.Message 
    }

Write-Progress "Task Bar User Pinned items"
    #Create directory info
    $from = "\\$oldPc\C$\Users\$username\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" + "\*"
    $Destination = "\\$newPc\C$\Users\$username\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
        #confirm directory path
        if (!(Test-path -path $Destination)) {
            new-item -path $Destination -itemtype "Directory"
        }
    Write-Progress "Copying TaskBar Pinned Apps" 
    try{
        Copy-item -Force -Recurse -path $from -destination $Destination -Exclude @("Explorer.lnk","File Explorer.lnk","Google Chrome.lnk","Internet Explorer.lnk")
        WriteHostDisplayAndLogFile "Successfully transfered: TaskBar Pinned Apps"
    } catch {
        WriteHostDisplayAndLogFile $_.Exception.Message
    }

#Exported MapDrives from old pc
    $from = "\\$oldPc\C$\Temp\MappedDrives.reg"
    $Destination = "\\$newPc\C$\Temp\"

    Write-Progress "Copy MappedDrives.reg  to $newPc Temp folder"
    try {
        Copy-item -Path $from -Destination $Destination
        WriteHostDisplayAndLogFile "Successfully transfered: MappedDrives.reg  to $newPc Temp folder"
    } catch {
        WriteHostDisplayAndLogFile $_.Exception.Message
    }

write-Host "---Completed profile data transfer!---" 
} #end of PostProfileCreation function
