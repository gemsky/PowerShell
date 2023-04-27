function Add-UserToLocalRdpGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,HelpMessage="Enter SAN number/Computer Name of the device")]
        [string]
        $computerName,
        [Parameter(Mandatory=$true,HelpMessage="Enter Users 'LastName, firtName' or what it starts with - to look up User Name")]
        [string]
        $Name
    )
    Write-Progress "Computer info look up and confirm online status"
    #$computerName = Read-Host "Enter SAN number"
    if (Test-Connection -ComputerName $computerName -Count 1 -quiet) {
        Write-Progress "$computerName is Online!"
         
    } else {
        Write-Host "$computerName is currently Offline Or unreachable - ending script!" -ForegroundColor Red
        Exit
    }   
    
    Write-Progress "Get userID to add..."
    $SamAccountName = $null
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
            #$Name = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
            try {
                $SamAccountName = (Get-ADUser $Name).SamAccountName
            }
            catch {
                #LookUp Relevant AD Account and display in consolegridview
                $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
                    Select-Object Name, SamAccountName |
                        Out-ConsoleGridView
    
                #Specify UserID
                $SamAccountName = $adObject.SamAccountName
            }
        } while ($SamAccountName -eq $null)
    } else {
        #LookUp UserID PowerShell 5.5
        do {
            #prompt for Name input following 'lastName, FirstName' format
            #$Name = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
            try {
                $SamAccountName = (Get-ADUser $Name).SamAccountName
            }
            catch {
                #LookUp Relevant AD Account and display in consolegridview
                $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
                    Select-Object Name, SamAccountName |
                        Out-GridView -PassThru
    
                #Specify UserID
                $SamAccountName = $adObject.SamAccountName
            }
        } while ($SamAccountName -eq $null)
    }
    write-host "Confirmed UserID is: $SamAccountName" -foregroundcolor green
    
    Invoke-Command -ComputerName $computerName -ScriptBlock { 
        Write-Progress "Validating Membership"
        $rdpUsers = Get-LocalGroupMember 'remote desktop users'
        if ($rdpUsers.Name -cmatch $using:SamAccountName){
            Write-Host "$using:SamAccountName is already member of $using:computerName 'remote desktop users' group"
        }else{
            Write-Progress "Confirmed user not member of group - Adding to local rdp group"
            try{
                Add-LocalGroupMember 'remote desktop users' -Member $using:SamAccountName
                Start-Sleep -Seconds 3
                Write-Progress "Validating Membership"
                $rdpUsers = Get-LocalGroupMember 'remote desktop users'
                if ($rdpUsers.Name -cmatch $SamAccountName){
                    Write-Host "Successfully added $using:SamAccountName to $computerName Local RDP Group, to allow Remote access to the PC." -ForegroundColor Green
                }else{
                    Write-Host "Unable to Confirm $using:SamAccountName is member of $computerName Local RDP Group." -ForegroundColor Red
                } 
            }catch{
                Write-Warning "Failed to add user to local rdp group"
                throw
            }
        }
    } 
} Add-UserToLocalRdpGroup