#Add users to local RDP group - Bulk
#Create User list
    #check else Create PTL Directory
    $uList = "c:\Temp\UserList.txt"
    if (!(test-path -path $uList)) {
        new-item -path $uList -itemtype File    
    } else {
        Clear-Content -Path $uList
    }
#Open Text file to enter hostnames
c:\Temp\UserList.txt
Write-Host "Enter userIDs in to Notepad that just opened, then Save changes and close it for connection test to proceed"

#Get Notepad Process
$nid = (Get-Process notepad).Id

#Wait for Notepad to close
Wait-Process -Id $nid

#Add users list to variable
$userNames = Get-Content -Path c:\Temp\UserList.txt

#Add computer to variable
$SanNumber = Read-Host "Enter SAN number"

#check online status
$onlineStatus = Test-Connection $SanNumber -count 1 -ErrorAction SilentlyContinue
if ($onlineStatus) {
    Write-Host "Device Online!" -ForegroundColor Green
} else {
    Write-Host "Device Offline!" -ForegroundColor Red
    exit
}

#For-Each Loop
foreach ($userName in $userNames) {
    Invoke-Command -ComputerName $SanNumber -ScriptBlock { 
                
        #validate
        $vm = (Get-LocalGroupMember 'remote desktop users').name -contains "$env:USERDOMAIN\$userName"
        if ($vm) {
            Write-Host "$userName is already member of local RDP group" -ForegroundColor Red
        } else {
            Write-Host "Adding $userName to local RDP group..." -ForegroundColor Yellow
            Add-LocalGroupMember 'remote desktop users' -Member $using:userName
            Write-Host "$userName successfully added to local RDP group" -ForegroundColor Green
        }
        
    } 
}

Write-Host "Invoke-Command -ScriptBlock { Add-LocalGroupMember 'remote desktop users' -Member $SamAccountName } -ComputerName $SanNumber"
