<#
.SYNOPSIS
AWS VM Provisioning and Setup Script.

.DESCRIPTION
This script automates the provisioning and setup of an AWS virtual machine (VM). It performs tasks such as joining the domain, setting the page file, adding the VM to the correct Organizational Unit (OU), updating Group Policy, installing the Configuration Manager (CCM) client, running CCM action items, enabling Nvidia graphics, and setting the screen resolution.

.EXAMPLE
.\AWSVMProvisioningScript.ps1 -DomainName "example.com" -OUPath "OU=VMs,OU=Computers,DC=example,DC=com" -PageFileSize 4096 -CCMSetupPath "C:\CCMSetup" -ScreenResolution "1920x1080"
Provisions and sets up an AWS VM by joining it to the "example.com" domain, adding it to the "OU=VMs,OU=Computers,DC=example,DC=com" OU, setting the page file size to 4GB, installing the CCM client from "C:\CCMSetup", setting the screen resolution to "1920x1080," and performing other necessary actions.

.NOTES
- Ensure you have the necessary permissions and valid credentials to perform the tasks within the VM.
- Modify the script to include additional customizations or tasks specific to your environment.
- Test the script thoroughly before using it in a production environment.
#>


#run this on AWS Machine with Powershell RunAs Admin
    #Change HostName and Join domain
    $hostname = Read-Host "Enter New Host Name"
    $Domain = Read-Host "Enter Domain name here"
    $Credential = Get-Credential

    Rename-Computer $hostname
    Add-Computer -Domain $Domain -NewName $hostname -Credential $Credential

    Write-Host "New Hostname: $hostname" -ForegroundColor Green
    Write-Host "Setting pagefile to 8192MB" -ForegroundColor Yellow

    # PowerShell Script to set the size of pagefile.sys
    $computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
    $computersys.AutomaticManagedPagefile = $False
    $computersys.Put()
    $pagefile = Get-WmiObject -Query "Select * From Win32_PageFileSetting Where Name like '%pagefile.sys'"
    $pagefile.InitialSize = "8192"
    $pagefile.MaximumSize = "8192"
    $pagefile.Put()

    Write-Host "HostName and pagefile setup completed - proceed to Move Ad computer account to new OU - then restart: Shutdown -f -r -t 01"
    Pause

    #Restart after moving AD Computer object to : OU=Exploration VDIs
    Shutdown -f -r -t 01

#Do this part on your EUC computer
    #Move AD Computer Account OU
    $CnToMove = Read-Host "Enter AWS hostname to move"
    Get-ADComputer $CnToMove | 
        Move-ADObject  -TargetPath "OU=Exploration VDIs,OU=Computers,OU=Windows,DC=santos,DC=com" -Verbose
    Get-ADComputer $CnToMove 
    Write-Host -NoNewline "$CnToMove has been successfully moved to 'Exploratin VDIs' OU." -ForegroundColor Green

#Log back in after restart to AWS with SAntosADM account and open powershell as Admin
    #GPupdate
        Invoke-GPUpdate -Force -AsJob
        
    #Install CCM client and Appsense, then wait 15 Minutes
    #Function to run batch files
        function Run-BatchFile ($Path) {
            #Tittle: This scriptis for running CMD or Bat files in powershell
            write-host "Checking file... $Path" -ForegroundColor Yellow

            if (Test-Path $Path ) {
                Write-host "File location confirmed" -ForegroundColor Green
                Write-host "Executing script..." -ForegroundColor Yellow
                $cs = "cmd.exe /C $Path"
                Invoke-Expression -Command $cs
            } else {
                Write-host "File $Path Not Found - please reconfirm!" -ForegroundColor Red
            }    
        }
    
    Run-BatchFile -path "C:\Temp\Configure_Appsense.cmd"
        Start-Sleep -Seconds 60

    Run-BatchFile -path "C:\Temp\CCMClient\Install-SCCM-Client.cmd"
        #Start sleep to let SCCM install
        Start-Sleep -Seconds 900

    # Run CCM Action items policy & Wait for applications to install in Software Center
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000121}"
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000121}"
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000026}"
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000027}"

    Start-Sleep -Seconds 900

#Disable Ms BAsic Display Adapter when 'NVIDIA Tesla T4 video adapter' is installed
    $gcwv = Get-CimInstance Win32_VideoController
    $t4 = $gcwv.name

    if ($t4 -eq "NVIDIA Tesla T4") {
        write-host "NVIDIA Tesla T4 is Installed!" -ForegroundColor Green
        Write-Host "Proceeding to disable 'Microsoft Basic Display Adapter'" -ForegroundColor Yellow
        
        #Check if NVIDIA Tesla T4 video adapter is installed
        $mbda = Get-PnpDevice | Where-Object {$_.FriendlyName -like "Microsoft Basic Display Adapter"}
        $mbdaStat = $mbda.Status
        if ($mbdaStat -eq "Error") {
            Write-Host " Microsoft Basic Display Adapter status is Already: Disabled - no further action" -ForegroundColor Green
        } else {
            Write-Host " Microsoft Basic Display Adapter status is still Enabled - proceeding to Disable driver..." -ForegroundColor Yellow
            Get-PnpDevice | Where-Object {$_.FriendlyName -like "Microsoft Basic Display Adapter"} |
                Disable-PnpDevice -Confirm:$False
            
            Write-Host " Microsoft Basic Display Adapter Disabled" -ForegroundColor Green
        }
        

    } else {
        Write-Host "NVIDIA Tesla T4 not yet detected - plase wait..." -ForegroundColor Red
    }

#Restart AWS Machine again: 
    Shutdown -f -r -t 01

#Connect with ZCentral Remote Boost

#Change the Display resolution to "1920 x 1080"
Function Set-ScreenResolution { 

    <# 
        .Synopsis 
            Sets the Screen Resolution of the primary monitor 
        .Description 
            Uses Pinvoke and ChangeDisplaySettings Win32API to make the change 
        .Example 
            Set-ScreenResolution -Width 1024 -Height 768         
        #> 
    param ( 
    [Parameter(Mandatory=$true, 
               Position = 0)] 
    [int] 
    $Width, 
    
    [Parameter(Mandatory=$true, 
               Position = 1)] 
    [int] 
    $Height 
    ) 
    
    $pinvokeCode = @" 
    
    using System; 
    using System.Runtime.InteropServices; 
    
    namespace Resolution 
    { 
    
        [StructLayout(LayoutKind.Sequential)] 
        public struct DEVMODE1 
        { 
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] 
            public string dmDeviceName; 
            public short dmSpecVersion; 
            public short dmDriverVersion; 
            public short dmSize; 
            public short dmDriverExtra; 
            public int dmFields; 
    
            public short dmOrientation; 
            public short dmPaperSize; 
            public short dmPaperLength; 
            public short dmPaperWidth; 
    
            public short dmScale; 
            public short dmCopies; 
            public short dmDefaultSource; 
            public short dmPrintQuality; 
            public short dmColor; 
            public short dmDuplex; 
            public short dmYResolution; 
            public short dmTTOption; 
            public short dmCollate; 
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] 
            public string dmFormName; 
            public short dmLogPixels; 
            public short dmBitsPerPel; 
            public int dmPelsWidth; 
            public int dmPelsHeight; 
    
            public int dmDisplayFlags; 
            public int dmDisplayFrequency; 
    
            public int dmICMMethod; 
            public int dmICMIntent; 
            public int dmMediaType; 
            public int dmDitherType; 
            public int dmReserved1; 
            public int dmReserved2; 
    
            public int dmPanningWidth; 
            public int dmPanningHeight; 
        }; 
    
    
    
        class User_32 
        { 
            [DllImport("user32.dll")] 
            public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE1 devMode); 
            [DllImport("user32.dll")] 
            public static extern int ChangeDisplaySettings(ref DEVMODE1 devMode, int flags); 
    
            public const int ENUM_CURRENT_SETTINGS = -1; 
            public const int CDS_UPDATEREGISTRY = 0x01; 
            public const int CDS_TEST = 0x02; 
            public const int DISP_CHANGE_SUCCESSFUL = 0; 
            public const int DISP_CHANGE_RESTART = 1; 
            public const int DISP_CHANGE_FAILED = -1; 
        } 
    
    
    
        public class PrmaryScreenResolution 
        { 
            static public string ChangeResolution(int width, int height) 
            { 
    
                DEVMODE1 dm = GetDevMode1(); 
    
                if (0 != User_32.EnumDisplaySettings(null, User_32.ENUM_CURRENT_SETTINGS, ref dm)) 
                { 
    
                    dm.dmPelsWidth = width; 
                    dm.dmPelsHeight = height; 
    
                    int iRet = User_32.ChangeDisplaySettings(ref dm, User_32.CDS_TEST); 
    
                    if (iRet == User_32.DISP_CHANGE_FAILED) 
                    { 
                        return "Unable To Process Your Request. Sorry For This Inconvenience."; 
                    } 
                    else 
                    { 
                        iRet = User_32.ChangeDisplaySettings(ref dm, User_32.CDS_UPDATEREGISTRY); 
                        switch (iRet) 
                        { 
                            case User_32.DISP_CHANGE_SUCCESSFUL: 
                                { 
                                    return "Success"; 
                                } 
                            case User_32.DISP_CHANGE_RESTART: 
                                { 
                                    return "You Need To Reboot For The Change To Happen.\n If You Feel Any Problem After Rebooting Your Machine\nThen Try To Change Resolution In Safe Mode."; 
                                } 
                            default: 
                                { 
                                    return "Failed To Change The Resolution"; 
                                } 
                        } 
    
                    } 
    
    
                } 
                else 
                { 
                    return "Failed To Change The Resolution."; 
                } 
            } 
    
            private static DEVMODE1 GetDevMode1() 
            { 
                DEVMODE1 dm = new DEVMODE1(); 
                dm.dmDeviceName = new String(new char[32]); 
                dm.dmFormName = new String(new char[32]); 
                dm.dmSize = (short)Marshal.SizeOf(dm); 
                return dm; 
            } 
        } 
    } 
"@
    
    Add-Type $pinvokeCode -ErrorAction SilentlyContinue 
    [Resolution.PrmaryScreenResolution]::ChangeResolution($width,$height) 
    } 
    Set-ScreenResolution -Width 1920 -Height 1080


#If Crowstrike not installing look for "WindowsSensor" in CCMcache
<#If First login always show Administrator, modify:
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
Change: AutoAdminLogon value to 0 #> 
