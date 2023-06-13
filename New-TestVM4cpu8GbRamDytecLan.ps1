<#
.SYNOPSIS
.DESCRIPTION
Defines the variables for the virtual machine name, path, virtual switch name, and ISO file path.
Creates a new virtual machine with the specified name and path using the New-VM cmdlet.
Adds a virtual hard disk to the virtual machine using the Add-VMHardDiskDrive cmdlet.
Sets the boot order to boot from the DVD drive using the Set-VMFirmware cmdlet.
Attaches the ISO file to the virtual DVD drive using the Add-VMDvdDrive cmdlet.
Connects the virtual machine to the specified virtual switch using the Connect-VMNetworkAdapter cmdlet.

.NOTES
In this example, the PowerShell script does the following:
Starts the virtual machine using the Start-VM cmdlet.
You can customize the script by modifying the variables to match your environment and provide the appropriate paths, names, and configurations for your virtual machine provisioning needs.
Please note that the script assumes you have the necessary permissions and prerequisites in your Hyper-V environment to create and manage virtual machines.

#>

$VMName = "My-VPCTest" 
$VMPath = "D:\Hyper-V\Virtual Hard Disks"
$SwitchName = "My_LAN"

# Create a new virtual machine
New-VM -Name $VMName -Path $VMPath -Generation 2

# Set the memory to 8GB
Set-VMMemory -VMName $VMName -StartupBytes 4GB

# Set the number of processor cores to 8
Set-VMProcessor -VMName $VMName -Count 2

# Add a virtual hard disk to the virtual machine
New-VHD -Path "$VMPath\$VMName.vhdx" -SizeBytes 127GB -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path "$VMPath\$VMName.vhdx" 

# Connect the virtual machine to the specified virtual switch
Connect-VMNetworkAdapter -VMName $VMName -SwitchName $SwitchName

# Enable PXE boot for the virtual machine
Set-VMFirmware -VMName $VMName -FirstBootDevice $(Get-VMNetworkAdapter -VMName $VMName) -EnableSecureBoot Off

# Start the virtual machine
Start-VM -Name $VMName
