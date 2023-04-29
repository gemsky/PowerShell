#Title: Get Machine stats
Write-Host "This Script is for collecting machine OS and hardware data" -ForegroundColor Blue

#Initialize empty array (Stores custom objects)
$allstats = @()

#Get name of computer
$machine = Read-Host "Enter Machine name"

#Create a custom object
$stats = @{
    MachineName = $machine
    TotalMemmoryGB = 0
    AvailableMemoryGB = 0
    Winver = ""
    OSInstalDate = ""
    SerialNumber = ""
    BiosVersion = ""
    BiosReleaseDate = ""
    Timezone = ""
    SystemBootTime = ""
    SystemManufacturer = ""
    SystemModel = ""
    FreeDiskSpaceGB = ""
    DiskSizeGB = ""
    ADGroupMembership = ""
}

#check if machine is online
if (Test-Connection -ComputerName $machine -Count 1 -quiet) {
    Write-Host "$machine is Online!" -ForegroundColor Green
    Write-Progress " Collecting data..."

    #Gather stats: 
        #WindowsVersion, BiosSeralNumber, BiosSMBIOSBIOSVersion, BiosStatus, TimeZone
        $bios = Invoke-Command -ScriptBlock { 
            Get-ComputerInfo
        } -ComputerName $machine
        
        #Hdd info
        $hdd = Invoke-Command -ScriptBlock { 
            Get-CimInstance -ClassName Win32_LogicalDisk | 
                Where-Object -property deviceID -eq "C:"
        } -ComputerName $machine

        #Computer Membership
        $Adgm = Get-ADPrincipalGroupMembership (Get-ADComputer $machine)

    #Load up customer object properties
    $stats.TotalMemmoryGB = [math]::Round(($bios.OsTotalVisibleMemorySize / 1MB), 2)
    $stats.AvailableMemoryGB = [math]::Round(($bios.OsFreePhysicalMemory / 1MB), 2)
    $stats.Winver = $bios.WindowsVersion
    $stats.OSInstalDate = $bios.WindowsInstallDateFromRegistry
    $stats.SerialNumber = $bios.BiosSeralNumber
    $stats.BiosVersion = $bios.BiosSMBIOSBIOSVersion
    $stats.BiosReleaseDate = $bios.BiosReleaseDate
    $stats.Timezone = $bios.TimeZone
    $stats.SystemBootTime = $bios.OsLastBootUpTime
    $stats.SystemManufacturer = $bios.CsManufacturer
    $stats.SystemModel = $bios.CsModel
    $stats.DiskSizeGB = [math]::Round(($hdd.size /1GB), 2)
    $stats.FreeDiskSpaceGB = [math]::Round(($hdd.FreeSpace /1GB), 2)
    $stats.ADGroupMembership = $Adgm.Name

    #add custom object to array
    $stats

    # #Output custom object array!
    # $allstats |
    #     Select-Object TotalMemmoryGB,
    #                     AvailableMemoryGB,
    #                     @{name='UsedMemoryGB';expression={$_.TotalMemmoryGB - $_.AvailableMemoryGB}},
    #                     Winver,
    #                     OSInstalDate,
    #                     SystemBootTime,
    #                     DiskSizeGB,
    #                     FreeDiskSpaceGB,
    #                     BiosVersion,
    #                     BiosReleaseDate,
    #                     Timezone,
    #                     SystemManufacturer,
    #                     SystemModel,
    #                     SerialNumber,
    #                     ADGroupMembership |
    #             Sort-Object Properties 
    
    #Get Device manager - drivers status
    Write-Host "
        Device Manager driver status:
        " -ForegroundColor Yellow
    
        Get-CimInstance Win32_PnPEntity -ComputerName $machine | 
        Sort-Object -Property Name | 
            Where-Object {$_.Status -ne 'OK'} | 
                Format-Table Name,status

} else {
    Write-Host "$machine is currently Offline Or unreachable - ending script!" -ForegroundColor Red
}