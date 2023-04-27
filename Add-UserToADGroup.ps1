Write-Host "==========================" -ForegroundColor Yellow
Write-Host "Script: Confirm userName and Add user to group " -ForegroundColor Yellow
Write-Host "==========================" -ForegroundColor Yellow
Write-Progress "Get userID to add..."
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
            $Name = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
            try {
                $userName = (Get-ADUser $Name).SamAccountName
            }
            catch {
                #LookUp Relevant AD Account and display in consolegridview
                $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
                    Select-Object Name, SamAccountName |
                        Out-ConsoleGridView
    
                #Specify UserID
                $userName = $adObject.SamAccountName
            }
        } while ($userName -eq $null)
    } else {
        #LookUp UserID PowerShell 5.5
        do {
            #prompt for Name input following 'lastName, FirstName' format
            $Name = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
            try {
                $userName = (Get-ADUser $Name).SamAccountName
            }
            catch {
                #LookUp Relevant AD Account and display in consolegridview
                $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
                    Select-Object Name, SamAccountName |
                        Out-GridView -PassThru
    
                #Specify UserID
                $userName = $adObject.SamAccountName
            }
        } while ($userName -eq $null)
    }
    write-host "Confirmed UserID is: $userName" -foregroundcolor green  

#Get Group details
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
    #Validate membership
    Write-Progress "Validate membership"
    $displayName = (get-aduser $UserName).name
    $Name = Get-ADGroupMember -identity $GroupName | 
                Select-Object Name | 
                    Where-Object {$_.Name -like $displayName}
    if ($Name) {
        Write-Host "$UserName is already member of $GroupName. Ending Script!" -ForegroundColor Red
    } else {
        #Add user to group
        Write-Progress "Updating user membership..."
        Add-ADGroupMember -Identity $GroupName -Members $UserName
        
        #Validate membership
        Write-Progress "Validate membership"
        $displayName = (get-aduser $UserName).name
        $Name = Get-ADGroupMember -identity $GroupName | 
                    Select-Object Name | 
                        Where-Object {$_.Name -like $displayName}
        if ($Name) {
            Write-Host -nonewline "Successfully added $UserName to $GroupName. Please give 1 hour for changes to take effect."
        }  
    }