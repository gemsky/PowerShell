#set-executionpolicy bypass for this process
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

function Get-RdpServiceStatus {
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Enter the user name to add to the Remote Desktop Users group")]
    [string]
    $UserName
)
<#
.SYNOPSIS
Checks the current status of Remote Desktop connections and Windows Firewall rules.

.DESCRIPTION
This script checks the current status of Remote Desktop connections and Windows Firewall rules for Remote Desktop. It displays whether Remote Desktop connections are enabled or disabled, and whether there is a Windows Firewall rule allowing incoming traffic to the Remote Desktop port (default port 3389) on a private network profile.

.REQUIREMENTS
Run this Script in an elevated PowerShell session as Administrator

.EXAMPLE
Check-RdpStatus.ps1
This command checks the current status of Remote Desktop connections and Windows Firewall rules for Remote Desktop.

.NOTES
Author: [G Lim]
Version: 1.0
Last Updated: [29/04/2023]

#> 

# Check if user account is already a member of Remote Desktop Users group
if (Get-LocalGroupMember -Group "Remote Desktop Users" | Where-Object {$_.Name -eq $UserName}) {
    Write-Host "User account is already a member of Remote Desktop Users group."
} else {
    Write-Warning "User account is not a member of Remote Desktop Users group."
}

# Check network connection profile and display the current category
$networkProfile = Get-NetConnectionProfile
Write-Host "Network Connection Profile: $($networkProfile.Name)"
Write-Host "Current Network Category: $($networkProfile.NetworkCategory)"

# Check if firewall rule exists for RDP traffic from Private network profile
$firewallRule = Get-NetFirewallRule -DisplayName "Allow RDP from Private network" -ErrorAction SilentlyContinue
if ($firewallRule) {
    Write-Host "Firewall rule for RDP traffic from Private network already exists."
} else {
    Write-Warning "Firewall rule for RDP traffic from Private network does not exist."
}

# Check if Remote Desktop is enabled and display the current setting
$rdpEnabled = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections").fDenyTSConnections
if ($rdpEnabled -eq 0) {
    Write-Host "Remote Desktop is already enabled."
} else {
    Write-Warning "Remote Desktop is not enabled."
}

# Disable Device Windows Hello PasswordLess reg 
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
$valueName = "DevicePasswordLessBuildVersion"
$currentValue = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue)."$valueName"
if ($currentValue -ne 0) {
    Write-Host "Windows Hello PasswordLess is currently enabled."
}
else {
    Write-Host "Windows Hello PasswordLess is turned off"
}

# Check if Remote Desktop Services is running and display the current status
$rdpService = Get-Service -Name TermService
if ($rdpService.Status -eq "Running") {
    Write-Host "Remote Desktop Services is running."
} else {
    Write-Warning "Remote Desktop Services is not running."
}    
} #end function Get-RdpServiceStatus

function Enable-RdpOnPrivateNetwork {[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Enter the user name to add to the Remote Desktop Users group")]
    [string]
    $UserName
)

<#
.SYNOPSIS
Enables Remote Desktop connections and allows incoming traffic to the Remote Desktop port in the Windows Firewall on a private network profile.

.DESCRIPTION
This script enables Remote Desktop connections and allows incoming traffic to the Remote Desktop port (default port 3389) in the Windows Firewall on a private network profile. It also checks if the current network profile is set to Private, and if not, sets it to Private.

.REQUIREMENTS
Run this Script in an elevated PowerShell session as Administrator

.EXAMPLE
Enable-RdpOnPrivateNetwork.ps1
This command enables Remote Desktop connections and allows incoming traffic to the Remote Desktop port in the Windows Firewall on a private network profile. If the current network profile is not set to Private, it will be set to Private.

.NOTES
Author: [G Lim]
Version: 1.0
Last Updated: [29/04/2023]

#> 

# Add user account to Remote Desktop Users group
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $UserName
Write-Host "User account added to Remote Desktop Users group."

# Check network connection profile and set it to Private if currently set to Public
$networkProfile = Get-NetConnectionProfile
if ($networkProfile.NetworkCategory -eq "Public") {
    Set-NetConnectionProfile -NetworkCategory Private
}
Write-Host "Network Connection Profile: $($networkProfile.Name)"

# Enable Remote Desktop inbound traffic from the Private network profile in the Windows Firewall
New-NetFirewallRule -DisplayName "Allow RDP from Private network" -Direction Inbound -LocalPort 3389 -Protocol TCP -Action Allow -Profile Private
Write-Host "Firewall rule for RDP traffic from Private network created."

# Disable DevicePasswordLess reg 
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
$valueName = "DevicePasswordLessBuildVersion"
$currentValue = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue)."$valueName"
if ($currentValue -ne 0) {
    Set-ItemProperty -Path $regPath -Name $valueName -Value 0 -Type DWORD
    Write-Host "DevicePasswordLess Value changed from $currentValue to 0."
}
else {
    Write-Host "DevicePasswordLess Value is already 0. No changes made."
}

# Enable Remote Desktop connections
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Write-Host "Remote Desktop enabled."

# Restart the Remote Desktop Services service
Restart-Service -Name TermService
Write-Host "Remote Desktop Services restarted."

} #end function Enable-RdpOnPrivateNetwork

Write-Host "This script checks the current status of Remote Desktop connections and Windows Firewall rules for Remote Desktop."
Write-Host "Select a function to run:"
Write-Host "Option 1: 'Get RDP Status'" 
Write-Host "Option 2: 'Enable RDP On Private Network'"
$Function = Read-Host "Please select option number function to run:"
$UserName = Read-Host "Please enter the user name to confirm/add to the Remote Desktop Users group:"

# Switch for user to choose which to run
switch ($Function) {
    "1" {
        Get-RdpServiceStatus -UserName $UserName
    }

    "2" {
        Enable-RdpOnPrivateNetwork -UserName $UserName
    }

    Default {
        Write-Warning "Invalid function selected. Please choose either 'Get RDP Status' or 'Enable Rdp On Private Network'"
        Exit 1
    }
}
