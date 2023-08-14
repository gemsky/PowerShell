<#
.SYNOPSIS
    Pre - Setup Script

.DESCRIPTION
    One Script to prepare OS  before Deployment.
    Includes:
    
    Systems & Policies
        PS Remoting
        firewall rule
        Cleanup WinSXS component folder
        Run Disk CleanUp
        Stop-Win11OSUpgradeAllow22H2
        Expand notification/tasktray
        Enable Default desktop icons for New Start Panel
        Enable Default desktop icons for Classic Start Menu
        Disable People button on Taskbar
        Disable Meet Now option from Task Tray
        Disable News and Interests from Task Tray
        Disable Cortana
        Change view of control panel to Large Icons instead of Category
        Set Explorer to open to This PC by default
        Set Explorer to show file extensions
        Unpin Store from taskbar
        Hide Task View
        Disable Fast User Switching
        Enable disk perfomrance counters in Task manager
        Powershell Get-AppxPackage Microsoft.windowscommunicationsapps - Un-install built-in Mail App
        Un-pin apps: Mail and Ms Store
        Set device to always on on power
        Set Adobe reader as default
        Set Timezone and Language
        Windows update settings
    
    Apps & Packages
        Remove unnecessary built-in Universal Windows Platform (UWP) apps 
        Check if Ms Hub is still there - if so, remove it
        Install Visual C++ Redistributable Packages
        .NET 3.5 Framework 
        Installing/Updating WinRAR
        Installing/Updating Adobe Reader
        Installing/Updating 7Zip
        Install Google Chrome for Enterprise
        Install Notepad++
        Install Office 365 ODT

    Updates
        Install Windows Updates for windows 10
        Check if PSWindowsUpdate is installed
        Schdule update every Second Monday of the month at 2AM
        
    Accounts
        Disable Administrator account
    
    User Experience
        Customize Windows Start Menu
        Disable MSFT Consumer Experience, First Logon Animation

    

.NOTES
    Only need to run this once during setup 

    PostBuildProcess list:
        Trusted Host and Firewall rule will need to be set after image is deployed in Start-MDTPostBuildProcess.ps1
        Anti virus added to Post-install script
        Add Printers

.Link
    Source: https://theitbros.com/capture-windows-10-reference-image/
    SysPrep OOBE andwer file solution: https://theitbros.com/sysprep-windows-machine/
#>

#Set execution policy to bypass for this script
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

function LogFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $message,
        [Parameter(Mandatory=$false, Position=1)]
        [switch]$Warning
    )
    #Validate Log file
    $global:logPath = "C:\Temp\PCSetup.Log"
    if (!(Test-Path $logPath)) {
        New-Item $logPath -ItemType File -Force
    }
    if ($Warning) {
        Write-Warning $message
        Write-Progress $message
        [String]"$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $message" | out-file -FilePath $logPath -Append    <# Action to perform if the condition is true #>
    } else {
        Write-Host $message -f Green
        Write-Progress $message
        [String]"$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $message" | out-file -FilePath $logPath -Append    <# Action when all if and elseif conditions are false #>
    }
    
    }

#make sure az.account module is installed
if (!(Get-Module -Name Az.Accounts)) {
    LogFunction "Installing Az.Accounts module"
    Install-Module -Name Az.Accounts -Force
    LogFunction "Az.Accounts module installed"
}

# make sure Az.KeyVault module is installed
if (!(Get-Module -Name Az.KeyVault)) {
    LogFunction "Installing Az.KeyVault module"
    Install-Module -Name Az.KeyVault -Force
    LogFunction "Az.KeyVault module installed"
}

#connect to Az
LogFunction "Connecting to Azure"
Connect-AzAccount
Set-AzContext -SubscriptionName "Azure Subscription 1"

#Get Get passwords from Azure Key Vault
    LogFunction "Getting passwords from Azure Key Vault"
    $KeyVaultName = Read-Host -Prompt "Enter Key Vault Name"

    #Get Device Admin password
    $secretAccount = Read-Host "Enter secret account name"
    $installerSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretAccount -AsPlainText


    $Path = Read-Host -Prompt "Enter path to CWC installer"
    #List content in gridview and get full path of selected file
    $CWC = Get-ChildItem -Path $Path | Select Name,FullName | sort Name | Out-GridView -Title "Select CWC Installer" -PassThru
    $CwcFullPath = $CWC.FullName

    #Install ScreenConnect aka CWC
    LogFunction "Installing/Updating CWC"
    #Copy $CwcFullPath to C:\Scratch\Software
    $destination = "C:\Scratch\Software"
    Copy-Item -Path $source -Destination $destination -Recurse -Force
    
    #Install CWC
    Start-Process -FilePath $CwcFullPath -Wait -NoNewWindow

#Find sysprep.exe process and kill it
LogFunction "Killing sysprep.exe process"
Get-Process -Name sysprep -ErrorAction SilentlyContinue | Stop-Process -Force

#System      
    #Rename computer
    LogFunction "Renaming computer"
    $newComputerName = Read-Host -Prompt "Enter new computer name"
    Rename-Computer -NewName $newComputerName -Force

    #Add to WorkGroup
    LogFunction "Adding computer to workgroup"
    $workGroup = "Workgroup"
    Add-Computer -WorkGroupName $workGroup -Force
    

    #Enable PS Remoting:
    LogFunction "Enabling PS Remoting"
        #Set network to private:
        if (((Get-NetConnectionProfile).NetworkCategory -ne "Private") -and ((Get-NetConnectionProfile).NetworkCategory -ne "DomainAuthenticated")) {
            LogFunction "Network is not set to private, setting network to private"
            Set-NetConnectionProfile -InterfaceAlias "Ethernet" -NetworkCategory Private -ErrorAction SilentlyContinue
            $status = (Get-NetConnectionProfile).NetworkCategory
            LogFunction "Network is set to $status"
        } else {
            LogFunction "Network is already set to private" -Warning

        }

        #create firewall rule
        LogFunction "Creating firewall rule"
        $FirewallParam = @{
            DisplayName = 'Windows Remote Management (HTTP-In)'
            Direction = 'Inbound'
            LocalPort = 5985
            Protocol = 'TCP'
            Action = 'Allow'
            Program = 'System'
            Profile = 'Private'
        }
        New-NetFirewallRule @FirewallParam
        LogFunction "Firewall rule created"

        #Get WinRM status and update
        LogFunction "Checking WinRM status"
        try {
            Enable-PSRemoting -Force
        }
        catch {
            Enable-PSRemoting -SkipNetworkProfileCheck -Force
        } #Trusted Host and Firewall rule will need to be set after 

        #Cleanup WinSXS component folder on Windows 10 using DISM:
        LogFunction "Cleaning up WinSXS component folder on Windows 10 using DISM"
            dism /Online /Cleanup-Image /AnalyzeComponentStore
            dism /online /Cleanup-Image /StartComponentCleanup

        
    #Expand notification/tasktray
    LogFunction "Expanding notification/tasktray"
        REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /V EnableAutoTray /T REG_DWORD /D 0 /F

    #Enable Default desktop icons for New Start Panel
    LogFunction "Enabling Default desktop icons for New Start Panel"
        $guids = @(
            "{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
            "{59031a47-3f72-44a7-89c5-5595fe6b30ee}",
            "{645FF040-5081-101B-9F08-00AA002F954E}",
            "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}",
            "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"
        )
        foreach ($guid in $guids) {    
            LogFunction "Setting $guid to 0"
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name $guid -Type DWord -Value 0 -Force
            LogFunction "Setting $guid to 0 - Complete"
        }        

    #Enable Default desktop icons for Classic Start Menu
    LogFunction "Enabling Default desktop icons for Classic Start Menu"
        $guids = @(
            "{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
            "{59031a47-3f72-44a7-89c5-5595fe6b30ee}",
            "{645FF040-5081-101B-9F08-00AA002F954E}",
            "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}",
            "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"
        )

        if (!(Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu")) {
            LogFunction "Creating HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu"
            New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" -Force
            LogFunction "Creating HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu - Complete"
        }

        foreach ($guid in $guids) {
            LogFunction "Setting $guid to 0"
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" -Name $guid -Type DWord -Value 0 -Force
            LogFunction "Setting $guid to 0 - Complete"
        }

    #Disable People button on Taskbar
    LogFunction "Disabling People button on Taskbar"
        REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V PeopleBand /T REG_DWORD /D 0 /F
	    REG ADD "HKCU\Software\Policies\Microsoft\Windows\Explorer" /V HidePeopleBar /T REG_DWORD /D 1 /F

    #Disable Meet Now option from Task Tray
    LogFunction "Disabling Meet Now option from Task Tray"
        REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /V HideSCAMeetNow /T REG_DWORD /D 1 /F
        REG ADD "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /V HideSCAMeetNow /T REG_DWORD /D 1 /F

    #Disable News and Intrest tool,bar widget
    LogFunction "Disabling News and Intrest tool,bar widget"
    	REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Feeds" /V ShellFeedsTaskbarViewMode /T REG_DWORD /D 2 /F

    #Hide Cortana
    LogFunction "Hiding Cortana"
        REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /V SearchboxTaskbarMode /T REG_DWORD /D 0 /F
        REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V ShowCortanaButton /T REG_DWORD /D 0 /F

	#Change view of control panel to Large Icons instead of Category
    LogFunction "Changing view of control panel to Large Icons instead of Category"
    	REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /V ForceClassicControlPanel /T REG_DWORD /D 1 /F

    #Set Explorer to open to This PC by default
    LogFunction "Setting Explorer to open to This PC by default"
    	REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V LaunchTo /T REG_DWORD /D 1 /F

    #Set Explorer to show file extensions
    LogFunction "Setting Explorer to show file extensions"
    	REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V HideFileExt /T REG_DWORD /D 0 /F

    #Unpin Store from taskbar
    LogFunction "Unpinning Store from taskbar"
    	REG ADD "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /V NoPinningStoreToTaskbar /T REG_DWORD /D 1 /F

    #Hide Task View
    LogFunction "Hiding Task View"
        if (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MultiTaskingView\AllUpView") {
            REG DELETE "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MultiTaskingView\AllUpView" /V Enabled /F
        }
        REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V ShowTaskViewButton /T REG_DWORD /D 0 /F

    #Disable Fast User Switching
    LogFunction "Disabling Fast User Switching"
      REG ADD "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /V HideFastUserSwitching /T REG_DWORD /D 1 /F
	
    #Enable disk perfomrance counters in Task manager
    LogFunction "Enabling disk perfomrance counters in Task manager"
    	diskperf -y

    #Powershell Get-AppxPackage Microsoft.windowscommunicationsapps - Un-install built-in Mail App
    LogFunction "Un-installing built-in Mail App"
	    Get-AppxPackage Microsoft.windowscommunicationsapps | Remove-AppxPackage

    #Un-pin apps
        function Remove-PinnedAppFromTaskbar {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory=$true,Position=0)]
                [string]
                $appName
            )
            ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() |
                ?{$_.Name -eq $appName}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} | %{$_.DoIt()}
        }
        LogFunction "Un-pinning Microsoft Store from taskbar"
        Remove-PinnedAppFromTaskbar -appName "Microsoft Store"

    #Kill and restart explorer
    LogFunction "Killing and restarting explorer"
        taskkill /f /im explorer.exe
            start explorer.exe

    #Set device to always on on power
    LogFunction "Setting device to always on on power"
            #Set power profile to High performance
            LogFunction "Setting power profile to High performance"
            powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
            
            #Set the plugged in settings to 'Never' (On power)
            LogFunction "Setting the plugged in settings to 'Never' (On power)"
            powercfg.exe -change -monitor-timeout-ac 0
            powercfg.exe -change -standby-timeout-ac 0
            powercfg.exe -change -hibernate-timeout-ac 0
            
            #Set the 'Dim Timeout' to Never
            LogFunction "Setting the 'Dim Timeout' to Never"
            powercfg -SETDCVALUEINDEX 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 7516b95f-f776-4464-8c53-06167f40cc99 17aaa29b-8b43-4b94-aafe-35f64daaf1ee 0
            powercfg -SETACVALUEINDEX 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 7516b95f-f776-4464-8c53-06167f40cc99 17aaa29b-8b43-4b94-aafe-35f64daaf1ee 0
            
            #Disable hibernation
            LogFunction "Disabling hibernation"
            powercfg -h off
            
            #Disable USB Selective Suspend
            LogFunction "Disabling USB Selective Suspend"
            powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

    #Set Timezone and Language
        Set-WinUILanguageOverride -Language en-AU
        Set-TimeZone -Name "W. Australia Standard Time"
        Set-WinSystemLocale -SystemLocale "en-AU"


    #Windows update settings
    LogFunction "Setting Windows update settings"
    if (!(Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\au")) {
        #create the key
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force
    }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0 -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0 -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 3 -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 0 -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "RebootRelaunchTimeoutEnabled" -Value 1 -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "RebootRelaunchTimeout" -Value 488 -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "RebootWarningTimeoutEnabled" -Value "00000001" -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "RebootWarningTimeout" -Value "0x0000001e" -Type DWord
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AutoInstallMinorUpdates" -Value "00000000" -Type DWord
            

#Packages
    #Ms App package clean up
        LogFunction "Removing unnecessary built-in Universal Windows Platform (UWP) apps"
        #Remove unnecessary built-in Universal Windows Platform (UWP) apps 
        $AppsList = "Microsoft.3DBuilder","microsoft.windowscommunicationsapps","Microsoft.MicrosoftOfficeHub","Microsoft.SkypeApp","Microsoft.Getstarted","Microsoft.ZuneMusic","Microsoft.MicrosoftSolitaireCollection","Microsoft.ZuneVideo","Microsoft.Office.OneNote","Microsoft.People","Microsoft.XboxApp", "Microsoft.Messaging", "Microsoft.Microsoft3DViewer", "Microsoft.WindowsFeedbackHub", "Microsoft.GetHelp", "Microsoft.OneConnect"
        ForEach ($App in $AppsList){
            $PackageFullName = (Get-AppxPackage $App).PackageFullName
            $ProPackageFullName = (Get-AppxProvisionedPackage -online | where {$_.Displayname -eq $App}).PackageName

            if ($PackageFullName){
            remove-AppxPackage -package $PackageFullName
            }

            if ($ProPackageFullName){
                    Remove-AppxProvisionedPackage -online -packagename $ProPackageFullName
            }
        }

    #Check if Ms Hub is still there - if so, remove it
    LogFunction "Removing Microsoft Office Hub"
    if (Get-AppxPackage -AllUsers | where {$_.PackageFullName -like 'Microsoft.MicrosoftOfficeHub_18.1903.1152.0_x64__8wekyb3d8bbwe'}) {
        $app = "Microsoft.MicrosoftOfficeHub_18.1903.1152.0_x64__8wekyb3d8bbwe"
        #After that, run one of the following command to remove the package or provision package.
        Remove-AppxPackage -Package $app -allusers
        
        #Remove the provisioning by running the following cmdlet:
        Remove-AppxProvisionedPackage -Online -PackageName $app -allusers
    }

#Apps
    #Install Core Apps with winget
        winget install --id=Microsoft.DotNet.Framework.DeveloperPack_4 -e  --scope machine
        winget install --id=Microsoft.DotNet.Framework.DeveloperPack_4 -e 
        winget install --scope machine --id=Microsoft.VCRedist.2015+.x64 -e
        winget install --scope machine --id=Adobe.Acrobat.Reader.64-bit -e
        winget install --scope machine --id=RARLab.WinRAR -e
        winget install --scope machine --id=7zip.7zip -e 
        winget install --scope machine --id=Google.Chrome -e 
        winget install --scope machine --id=Notepad++.Notepad++ -e

#M365 ODT installation
                 
#Updates
    #Install Windows Updates for windows 10
    LogFunction "Installing Windows Updates"
        #check if nuget is installed
        LogFunction "Checking if NuGet is installed"
        if (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue) {
            Write-Host "NuGet is already installed." -ForegroundColor Green
        } else {
            Write-Host "NuGet is not installed. Installing..." -ForegroundColor Yellow
            Install-PackageProvider -Name NuGet -Force -Scope AllUsers
        }
        
        #Check if PSWindowsUpdate is installed
        LogFunction "Checking if PSWindowsUpdate is installed"
        if (!(Get-Module -Name PSWindowsUpdate -ListAvailable)) {
            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
        } else {
            Write-Host "PSWindowsUpdate module is already installed." -ForegroundColor Green
        }

        # get all updates and install them
        LogFunction "Getting and installing all updates"
        Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot -IgnoreReboot -Verbose

        #Schdule update every Second Monday of the month at 2AM
            $taskName = "InstallWinUpdatesEvery2ndMondayOfMonth"
            $user = "NT AUTHORITY\SYSTEM"
            $privileges = "HIGHEST"
            $action = "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File $filepath"
            #confirm if task exists, if yess unregister it
            if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
            SCHTASKS /CREATE /SC MONTHLY /mo FIRST /d  MON /st 02:00 /RU $user /RL $privileges /TN $taskName /TR $action

#Accounts
    #Disable Administrator account
    LogFunction "Disabling Administrator account"
        net user Administrator /active:no
  
    #Disable localuser account
    if ((Get-LocalUser -Name "localuser" -ErrorAction SilentlyContinue).ENABLED -eq $true) {
        Get-LocalUser -Name "localuser"  | Disable-LocalUser
    }
            

#User Experience
    # Customize Windows Start Menu
    LogFunction "Customizing Windows Start Menu"
    $Path = "C:\Scratch\Powershell\StartMenuLayout.xml"
    Export-StartLayout -path $Path
    Copy-Item $Path -Destination “C:\Users\Default\AppData\Local\Microsoft\Windows\Shell”

    #Disable MSFT Consumer Experience, First Logon Animation
    LogFunction "Disabling MSFT Consumer Experience, First Logon Animation"
        # Disable the Microsoft Consumer Experience
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\ -Name CloudContent
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -name 'DisableWindowsConsumerFeatures' -PropertyType DWORD -Value '1'

        # Disable First logon Animation
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -name 'EnableFirstLogonAnimation' -PropertyType DWORD -Value '0'

#Set Execution Policy
    LogFunction "Setting Execution Policy"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

#remove winget app for sysprep
    Get-AppxPackage -Name Microsoft.Winget.Source | Remove-AppxPackage

#Trigger Sysprep    
    $command = 'c:\windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Scratch\Scripts\Unattend.xml'
    Invoke-Expression -Command $command
    
#End of script
