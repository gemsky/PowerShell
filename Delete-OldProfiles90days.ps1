#Delete Old profiles 
$computerName = Read-Host "Enter SanNumber to delete old profiles"
#Get Current C drive Size
Write-Progress "Check hdd size"
    $hddSize = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $computerName | 
        Where-Object -property deviceID -eq "C:" | 
            Select-Object @{name='FreeSpace';Expression={[math]::Round(($_.FreeSpace /1GB), 2)}},@{name='Size';Expression={[math]::Round(($_.size /1GB), 2)}}
    $FreeSpaceBefore = $hddSize.FreeSpace
    $size = $hddSize.size
    Write-Host "$computerName FreeSpace before cleanup: $FreeSpaceBefore/$size GB" -ForegroundColor Yellow

#Create Log of current list of profies
        #LogName by Date
        $date = Get-Date -Format yyyyMMdd
        $profileLog = "$computerName"+"ProfileCleanupLog"+$date+".txt"
        $path = "\\$computerName\C$\Scratch"
        $logPath = "$path\$profileLog"

    #Create file
        New-Item -Path $path -Name $profileLog | Out-Null

    
    #Outfile csv
        Get-ChildItem \\$computerName\C$\Users\ | select Name,LastWriteTime | Sort-Object Name | Out-File $logPath
    
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
    $userProfiles = Get-ChildItem \\$computerName\C$\Users\ |
        Where-Object {$_.LastWriteTime -lt [datetime]::Today.AddDays(-90)}
    $userProfileNames = $userProfiles.name
    foreach($profile in $userProfileNames){
        Write-Progress "Found Old profiles: > 90 days - $profile"
        $adInfo = Get-ADUser $profile -Properties LastLogonDate -ErrorAction SilentlyContinue
        $oldProfiles90 += $adInfo    
    }
    $totalOP90 = $oldProfiles90.count
    Write-Host "Total Old Profile > 90 days: $totalOP90" -ForegroundColor Yellow
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

#Get Current C drive Size
Write-Progress "Check hdd size"
    $hddSize = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $computerName | 
        Where-Object -property deviceID -eq "C:" | 
            Select-Object @{name='FreeSpace';Expression={[math]::Round(($_.FreeSpace /1GB), 2)}},@{name='Size';Expression={[math]::Round(($_.size /1GB), 2)}}
    $FreeSpaceBefore = $hddSize.FreeSpace
    $size = $hddSize.size
    Write-Host "$computerName FreeSpace before cleanup: $FreeSpaceBefore/$size GB" -ForegroundColor Yellow