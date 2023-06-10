<#
.SYNOPSIS
The script performs a cleanup operation on a specified computer, targeting the C drive. It deletes old user profiles, removes temporary files, cleans up Windows Update files, and performs various other cleanup tasks. It can be run remotely by providing the computer name as a parameter.

.DESCRIPTION
The script automates the cleanup process on a specified computer, allowing users to reclaim disk space and remove unnecessary files. It supports remote execution by providing the computer name as a parameter. The script first checks if the computer is online and proceeds with the cleanup if it's accessible.

During the cleanup, the script performs the following tasks:

Deletes old user profiles: It removes user profiles that haven't been used for a specified number of days (default: > 90 days), excluding profiles listed in the exception list.
Deletes old OST files: It removes Outlook OST files that haven't been modified for a specified number of days (default: > 60 days).
Clears C drive files: It removes various temporary files and folders, including Windows SoftwareDistribution, Windows Temp, user-specific Temp folders, and Temporary Internet Files. It also deletes CBS logs, IIS logs, Config.Msi folder, Intel folder, PerfLogs folder, and memory dump files.
Performs additional cleanup tasks: It deletes rouge folders and Windows Error Reporting files.
The script provides progress updates and generates a log file containing information about the cleanup operation, such as the current user profiles count, deleted profiles, deleted OST files, and the final user profiles count after the cleanup.

.NOTES
Please note that the script should be used with caution and thoroughly tested in a non-production environment before running it in a production environment.
#>

[CmdletBinding()]
param (
# Specifies a path to one or more locations. Wildcards are permitted.
[Parameter(Mandatory=$true,
           Position=0,
           ParameterSetName="Computer Name",
           HelpMessage="Enter computer Name for C drive clean up")]
[ValidateNotNullOrEmpty()]
[SupportsWildcards()]
[string]
$computerName 
)

#Exception list
$exceptionList = @()
$query = Read-Host 'Do you need to use the exception list? (Y/N)'
if ($query -eq "y") {


    Write-Progress "Opening Exception list..."
    #Update UserIds to Text file
        #Open Text file to enter UserIDs
        $path = "\\$computerName\C$\Temp\"
        $fileName = "ExceptionList.txt"
        $filePath = $path+$fileName
        if (!(Test-Path $filePath)) {
            New-Item -Path $path -Name $fileName -ItemType "file" | Out-Null
        }
        Set-Content -Path $filePath -value 'EXCEPTION LIST' 
        Add-Content -Path $filePath -value 'Delete all text content and Enter userIDs of profiles  you do NOT want to delete with this script'
        Add-Content -Path $filePath -value 'Note: One userID per Line with no space at the end.'
        Add-Content -Path $filePath -value 'Save changes and close NotePad to proceed'
        Start-Process $filePath
        Write-Host "Enter 'UserNames'  in to Notepad that just opened, then Save changes and close it to proceed" -foregroundcolor Yellow
        Write-Warning "Make sure all open Notepads are closed, for process to proceed"

        #Get Notepad Process
        $nid = (Get-Process notepad).Id

        #Wait for Notepad to close
        Wait-Process -Id $nid

        #Add App Collection to variable
        $exceptionList = Get-Content $filePath
}

#check if machine is online
    if (!(Test-Connection -ComputerName $computerName -Count 1 -quiet)) {
        Write-Host "$computerName is Offline!" -ForegroundColor red  
        Exit  
    }
    write-progress "$computerName is Online!"
    write-progress " Starting Clean up..."

#Get Current C drive Size
Write-Progress "Check hdd size"
    $hddSize = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $computerName | 
        Where-Object -property deviceID -eq "C:" | 
            Select-Object @{name='FreeSpace';Expression={[math]::Round(($_.FreeSpace /1GB), 2)}},@{name='Size';Expression={[math]::Round(($_.size /1GB), 2)}}
    $FreeSpaceBefore = $hddSize.FreeSpace
    $size = $hddSize.size
    Write-Host "$computerName FreeSpace before cleanup: $FreeSpaceBefore/$size GB" -ForegroundColor Yellow

    
#Delete Old profiles 
    Invoke-Command -ComputerName $computerName -ScriptBlock { 
        #Turn off hibernate
        $cmdText = "powercfg.exe /hibernate off"
        $cs = "cmd.exe /C $cmdText"
            Invoke-Expression -Command $cs
    }        
    #Create Log of current list of profies
        #LogName by Date
            $date = Get-Date -Format yyyyMMdd
            $profileLog = "ProfileCleanupLog"+$date+".txt"
            $path = "\\$computerName\C$\Scratch"
            $logPath = "$path\$profileLog"

        #Create file
            New-Item -Path $path -Name $profileLog | Out-Null

        #Outfile csv
            Get-ChildItem C:\Users\ | select Name,LastWriteTime | Sort-Object Name | Out-File $logPath
    
    #Count total user profiles
        Write-Progress "Count total user profiles"
        $userProfile = Get-CimInstance win32_Userprofile -ComputerName $computerName
        $count = $userProfile.count
        Write-Host "Current Profiles Total: $count"  -ForegroundColor Yellow

    #defaultUser profiles: temp sys folders
    Write-Progress  "Remove DefaultUser folders"
        Write-Progress "Get DefaultUsers list"
        $userProfiles = Get-CimInstance win32_Userprofile -computerName $computerName
        $defaultUsers = $userProfiles | Where-Object {$_.LocalPath -like "C:\Users\defaultuser*"}
        $SIDs = $defaultUsers.SID
        $totalSIDs = $SIDs.count
        Write-Host "Total tempsys profiles: $totalSIDs" -ForegroundColor Yellow

        #Delete profiles of defaultUsers
        foreach ($SID in $SIDs) {
            Write-Progress "Deleting Default profile: $SID"
            try{
                Remove-Ciminstance -ComputerName $computerName -Query "Select * from Win32_Userprofile where SID LIKE '$SID'" -ErrorAction SilentlyContinue
            }catch{
                throw $SID
            }
        }

    #Get Old profiles: > 90 days - Source: AD LastLogon attribute
    Write-Progress "Get Old profiles: > 90 days"
        $oldProfiles90 = @()
        $userProfiles = Get-ChildItem \\$computerName\C$\Users\
        $userProfileNames = $userProfiles.name
        foreach($profile in $userProfileNames){
            try { Write-Progress "Found Old profiles: > 90 days - $profile"
                $adInfo = Get-ADUser $profile -Properties LastLogonDate    
                if ($adInfo.LastLogonDate -le (Get-Date).AddDays(-90) -and $exceptionList -notcontains $profile) {
                    $oldProfiles90 += $adInfo
                }
            }   catch { }
        }
        $totalOP90 = $oldProfiles90.count
        Write-Host "Total Old Profile > 90 days: $totalOP90" -ForegroundColor Yellow
        $oldProfiles90 | sort LastLogonDate | select SamAccountName,LastLogonDate,Enabled
        $SIDs = $oldProfiles90.sid.value

        #Delete profiles of OldProfiles90
        foreach ($SID in $SIDs) {
            Write-Progress "Deleting OldProfiles90 profile: $SID"
            try{
                Remove-Ciminstance -ComputerName $computerName -Query "Select * from Win32_Userprofile where SID LIKE '$SID'" -ErrorAction SilentlyContinue
            }catch{
                throw $SID
            }
        }

    #Delete Old Ost from profiles: > 30 days = Remove ost file - urL https://community.spiceworks.com/topic/2209444-powershell-script-to-delete-ost-file-for-all-users
    Write-Progress "GetList: Old Ost from profiles: > 60 days"
        $oldOstFiles30 = @()
        $userProfiles = Get-ChildItem \\$computerName\C$\Users\
        $userProfileNames = $userProfiles.name
        foreach ($user in $userProfileNames){
            $folder = "\\$computerName\C$\users\$user\AppData\Local\Microsoft\Outlook" 
            $folderpath = test-path -Path $folder
            Write-Progress "Confirm Old Ost: $folder"
            if($folderpath){
                try {
                    $ost = Get-ChildItem $folder -filter *.ost | 
                    where-object {($_.LastWriteTime -le (Get-Date).AddDays(-60)) <#-and ($_.Length /500MB -gt 1)#>}
                    $oldOstFiles30 += $ost    
                }
                catch {
                    throw $ost
                }
            }
        }  $totalOldOst = $oldOstFiles30.count
        Write-Host "Total Old Ost files: $totalOldOst" -ForegroundColor Yellow

        Write-Progress "Delete Old Ost from profiles: > 60 days"
        foreach ($oldOst in $oldOstFiles30){
            $oldOstName = $oldOst.Name
            Write-Progress "Deleting: $oldOstName"
            $oldOst | Remove-Item
        }

    #Count total user profiles - after clean up
    Write-Progress "Count total user profiles - after clean up"
    $userProfile = Get-CimInstance win32_Userprofile -ComputerName $computerName
    $count = $userProfile.count
    Write-Host "Total Profiles after Clean Up: $count"  -ForegroundColor Green

#Clear C drive files 
Write-Progress "Connecting to $computerName "
Invoke-Command -ComputerName $computerName -ScriptBlock {
    Function Start-Cleanup {
        ## Allows the use of -WhatIf
        [CmdletBinding(SupportsShouldProcess=$True)]
        param(
            ## Delete data older then $daystodelete
            [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)]
            $DaysToDelete = 7,
        
            ## All errors should be withheld from the console
            [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=3)]
            $ErrorActionPreference = "SilentlyContinue"
        )            
        Write-Progress "Clearing C drive files "
            ## Stops the windows update service so that c:\windows\softwaredistribution can be cleaned up
            Get-Service -Name wuauserv | Stop-Service -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 
        
            # Sets the SCCM cache size to 1 GB if it exists.
            if ((Get-Ciminstance -namespace root\ccm\SoftMgmtAgent -class CacheConfig) -ne "$null"){
                # if data is returned and sccm cache is configured it will shrink the size to 1024MB.
                $cache = Get-CimInstance -namespace root\ccm\SoftMgmtAgent -class CacheConfig
                $Cache.size = 1024 | Out-Null
                $Cache.Put() | Out-Null
                Restart-Service ccmexec -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
        
            ## Deletes the contents of windows software distribution.
            Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -recurse -ErrorAction SilentlyContinue 
            Write-Progress "The Contents of Windows SoftwareDistribution have been removed successfully!                      " 
            
        
            ## Deletes the contents of the Windows Temp folder.
            Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force  -ErrorAction SilentlyContinue |
                Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete)) } | Remove-Item -force -recurse -ErrorAction SilentlyContinue 
            Write-Progress "The Contents of Windows Temp have been removed successfully!                                      " 
            
        
        
            ## Deletes all files and folders in user's Temp folder older then $DaysToDelete
            Get-ChildItem "C:\users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete))} |
                Remove-Item -force -recurse -ErrorAction SilentlyContinue 
            Write-Progress "The contents of $env:TEMP have been removed successfully!                                         " 
            
        
            ## Removes all files and folders in user's Temporary Internet Files older then $DaysToDelete
            Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" `
                -Recurse -Force  -ErrorAction SilentlyContinue |
                Where-Object {($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete))} |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue 
            Write-Progress "All Temporary Internet Files have been removed successfully!                                      " 
            
        
            ## Removes *.log from C:\windows\CBS
            if(Test-Path C:\Windows\logs\CBS\){
            Get-ChildItem "C:\Windows\logs\CBS\*.log" -Recurse -Force -ErrorAction SilentlyContinue |
                remove-item -force -recurse -ErrorAction SilentlyContinue 
            Write-Progress "All CBS logs have been removed successfully!                                                      " 
            
            } else {
                Write-Progress "C:\inetpub\logs\LogFiles\ does not exist, there is nothing to cleanup.                         " 
                
            }
        
            ## Cleans IIS Logs older then $DaysToDelete
            if (Test-Path C:\inetpub\logs\LogFiles\) {
                Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-90)) } | Remove-Item -Force  -Recurse -ErrorAction SilentlyContinue
                Write-Progress "All IIS Logfiles over $DaysToDelete days old have been removed Successfully!                  " 
                
            }
            else {
                Write-Progress "C:\Windows\logs\CBS\ does not exist, there is nothing to cleanup.                                 " 
                
            }
        
            ## Removes C:\Config.Msi
            if (test-path C:\Config.Msi){
                remove-item -Path C:\Config.Msi -force -recurse  -ErrorAction SilentlyContinue
            } else {
                Write-Progress "C:\Config.Msi does not exist, there is nothing to cleanup.                                        " 
                
            }
        
            ## Removes c:\Intel
            if (test-path c:\Intel){
                remove-item -Path c:\Intel -force -recurse  -ErrorAction SilentlyContinue
            } else {
                Write-Progress "c:\Intel does not exist, there is nothing to cleanup.                                             " 
                
            }
        
            ## Removes c:\PerfLogs
            if (test-path c:\PerfLogs){
                remove-item -Path c:\PerfLogs -force -recurse  -ErrorAction SilentlyContinue
            } else {
                Write-Progress "c:\PerfLogs does not exist, there is nothing to cleanup.                                          " 
                
            }
        
            ## Removes $env:windir\memory.dmp
            if (test-path $env:windir\memory.dmp){
                remove-item $env:windir\memory.dmp -force  -ErrorAction SilentlyContinue
            } else {
                Write-Progress "C:\Windows\memory.dmp does not exist, there is nothing to cleanup.                                " 
                
            }
        
            ## Removes rouge folders
            Write-Progress "Deleting Rouge folders                                                                            " 
            
        
            ## Removes Windows Error Reporting files
            if (test-path C:\ProgramData\Microsoft\Windows\WER){
                Get-ChildItem -Path C:\ProgramData\Microsoft\Windows\WER -Recurse | Remove-Item -force -recurse  -ErrorAction SilentlyContinue
                    Write-Progress "Deleting Windows Error Reporting files                                                            " 
                    
                } else {
                    Write-Progress "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup.            " 
                    
            }
        
            ## Removes System and User Temp Files - lots of access denied will occur.
            ## Cleans up c:\windows\temp
            if (Test-Path $env:windir\Temp\) {
                Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Windows\Temp does not exist, there is nothing to cleanup.                                 " 
                    
            }
        
            ## Cleans up minidump
            if (Test-Path $env:windir\minidump\) {
                Remove-Item -Path "$env:windir\minidump\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "$env:windir\minidump\ does not exist, there is nothing to cleanup.                           " 
                    
            }
        
            ## Cleans up prefetch
            if (Test-Path $env:windir\Prefetch\) {
                Remove-Item -Path "$env:windir\Prefetch\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "$env:windir\Prefetch\ does not exist, there is nothing to cleanup.                           " 
                    
            }
        
            ## Cleans up each users temp folder
            if (Test-Path "C:\Users\*\AppData\Local\Temp\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Temp\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Temp\ does not exist, there is nothing to cleanup.                  " 
                    
            }
        
            ## Cleans up all users windows error reporting
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup.            " 
                    
            }
        
            ## Cleans up users temporary internet files
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\ does not exist.              " 
                    
            }
        
            ## Cleans up Internet Explorer cache
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\ does not exist.                         " 
                    
            }
        
            ## Cleans up Internet Explorer cache
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\ does not exist.                       " 
                    
            }
        
            ## Cleans up Internet Explorer download history
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\ does not exist.                     " 
                    
            }
        
            ## Cleans up Internet Cache
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\ does not exist.                             " 
                    
            }
        
            ## Cleans up Internet Cookies
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\ does not exist.                           " 
                    
            }
        
            ## Cleans up terminal server cache
            if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\") {
                Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\*" -Force -Recurse  -ErrorAction SilentlyContinue
            } else {
                    Write-Progress "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\ does not exist.                  " 
                    
            }
        
            Write-Progress "Removing System and User Temp Files                                                               " 
            
        
            ## Removes the hidden recycling bin.
            if (Test-path 'C:\$Recycle.Bin'){
                Remove-Item 'C:\$Recycle.Bin' -Recurse -Force  -ErrorAction SilentlyContinue
            } else {
                Write-Progress "C:\`$Recycle.Bin does not exist, there is nothing to cleanup.                                      " 
                
            }
        
            ## Turns errors back on
            $ErrorActionPreference = "Continue"
        
            ## Checks the version of PowerShell
            ## If PowerShell version 4 or below is installed the following will process
            if ($PSVersionTable.PSVersion.Major -le 4) {
        
                ## Empties the recycling bin, the desktop recyling bin
                $Recycler = (New-Object -ComObject Shell.Application).NameSpace(0xa)
                $Recycler.items() | ForEach-Object { 
                    ## If PowerShell version 4 or bewlow is installed the following will process
                    Remove-Item -Include $_.path -Force -Recurse 
                    Write-Progress "The recycling bin has been cleaned up successfully!                                        " 
                    
                }
            } elseif ($PSVersionTable.PSVersion.Major -ge 5) {
                ## If PowerShell version 5 is running on the machine the following will process
                Clear-RecycleBin -DriveLetter C:\ -Force 
                Write-Progress "The recycling bin has been cleaned up successfully!                                               " 
                
            }
            ## Restarts wuauserv
            Get-Service -Name wuauserv | Start-Service -ErrorAction SilentlyContinue        
        }
        Start-Cleanup

    Write-Progress "Check hdd size"
    $hddSize = Get-CimInstance -ClassName Win32_LogicalDisk | 
        Where-Object -property deviceID -eq "C:" | 
            Select-Object @{name='FreeSpace';Expression={[math]::Round(($_.FreeSpace /1GB), 2)}},@{name='Size';Expression={[math]::Round(($_.size /1GB), 2)}}
    $FreeSpace = $hddSize.FreeSpace
    $size = $hddSize.size
    Write-Host "Dear Customer,"     -ForegroundColor Green
    Write-Host ""
    Write-Host "I have completed C drive clean up." -ForegroundColor Green
    Write-Host ""
    Write-Host "Please restart device and confirm computer performance after C drive clean up:" -ForegroundColor Green
    Write-Host "$computerName FreeSpace before cleanup: $using:FreeSpaceBefore/$size GB"  -ForegroundColor Green
    Write-Host "$computerName FreeSpace after cleanup: $FreeSpace/$size GB" -ForegroundColor Green
    Write-Host ""
    Write-Host "Have a safe and wonderful day, "  -ForegroundColor Green
    Write-Host ""
    Write-Host "EUC Analyst | Customer Success Team - IS"  -ForegroundColor Green

    #Find Big files: 
    $computerName = hostname
    write-progress "Find Big files: "
    Write-Host "================================" -ForegroundColor Yellow
    Write-Host "Top 10 largest files on C drive:" -ForegroundColor Yellow
    Write-Host "++++++++++++++++++++++++++++++++" -ForegroundColor Yellow
    
    Get-ChildItem -Recurse -Path "C:\" -ErrorAction SilentlyContinue |
        Sort-Object -descending -property length | 
            Select-Object -first 10 name, @{Name="Gigabytes";Expression={[Math]::round($_.length / 1GB, 2)}},Directory | 
                Format-Table Name,Gigabytes,Directory
        #source: https://4sysops.com/archives/finding-large-files-with-powershell/
}
