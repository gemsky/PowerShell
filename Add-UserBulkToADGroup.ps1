#Get Group details
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

do {
    $keyword = Read-Host "Enter AD Group Name"
    if (($PSVersionTable.PSVersion.Major) -eq 5) {
    #If Pshell is V major 5
    $GroupName = (Get-ADGroup -Filter "Name -like '$keyword*'" -Properties Name, Description, info | 
        Select-Object Name, Description, info |
            Out-GridView -title "Select Correct Group and click 'OK'" -PassThru).Name   
    Write-Host "Group selected: $GroupName"  -ForegroundColor Green
    } else {
    #If PShel V 6,2 and above
    $GroupName = (Get-ADGroup -Filter "Name -like '$keyword*'" -Properties Name, Description, info | 
        Select-Object Name, Description, info |
            Out-ConsoleGridView -title "Select correct group and press Enter").Name
    Write-Host "Group selected: $GroupName"  -ForegroundColor Green
    }
} while ($GroupName -eq $null)

#Add UserName to AD Group

foreach ($userName in $userNames) {

    #Validate membership
    Write-Progress "Validate membership $userName"
    $displayName = (get-aduser $UserName).name
    $Name = Get-ADGroupMember -identity $GroupName | 
                Select-Object Name | 
                    Where-Object {$_.Name -like $displayName}
    if ($Name) {
        Write-Host "$UserName is already member of $GroupName. Ending Script!" -ForegroundColor Red
    } else {
        #Add user to group
        Write-Progress "Updating user membership... $userName"
        Add-ADGroupMember -Identity $GroupName -Members $UserName
        
        #Validate membership
        Write-Progress "Validate membership"
        $displayName = (get-aduser $UserName).name
        $Name = Get-ADGroupMember -identity $GroupName | 
                    Select-Object Name | 
                        Where-Object {$_.Name -like $displayName}
        if ($Name) {
            Write-Host -nonewline "Successfully added $UserName to $GroupName. Please give 1 hour for changes to take effect."
            Write-Host " "
        }  
    }
}