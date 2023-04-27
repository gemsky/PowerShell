<#
.SYNOPSIS
Get users account info
.DESCRIPTION
If Account is disabled = prompt and exit.
If account is locked out = Request confirmation and give option to Unlock
.PARAMETER userID
If $script:userID parameter = $null then prompt user to look up user in AD and enter userID
.INPUTS
System.String. 
.OUTPUTS
None
.EXAMPLE
User function with no parameter or argument:
getuserinfo

1st prompt: "Enter User Display name (LastName, FirstName) to Look up UserID"
This readHost argument uses a wildcard: so you can enter first few letters and it will display relevant accounts by displayName.

2nd prompt: "Enter SamAccountName to get Status"
Copy and paste the relevant SamAccountName to get desired account info.

.EXAMPLE
Use function -parameter argument method:
getuserinfo -userID limge

.EXAMPLE
User Function, skip parameter and use argument directly:
getuserinfo limge
#>

Write-Progress "Get userID to add..."
#Validate module: consoleGuiTools
if ($PSVersionTable.PSVersion.Major -ge 7) {
    if (!(Get-InstalledModule -name microsoft.powershell.ConsoleGuiTools)) {
    #Install GUI Tools
        Write-Progress "Installing Module"
        Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Force
    }  

    #LookUp UserID PowerShell 7
    do {
        #prompt for Name input following 'lastName, FirstName' format
        $Name = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
        try {
            $script:userID = (Get-ADUser $Name).SamAccountName
        }
        catch {
            #LookUp Relevant AD Account and display in consolegridview
            $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
                Select-Object Name, SamAccountName |
                    Out-ConsoleGridView

            #Specify UserID
            $script:userID = $adObject.SamAccountName
        }
    } while ($script:userID -eq $null)
} else {
    #LookUp UserID PowerShell 5.5
    do {
        #prompt for Name input following 'lastName, FirstName' format
        $Name = Read-Host "Enter UserID OR User Display name (LastName, FirstName) to Look up UserID"
        try {
            $script:userID = (Get-ADUser $Name).SamAccountName
        }
        catch {
            #LookUp Relevant AD Account and display in consolegridview
            $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
                Select-Object Name, SamAccountName |
                    Out-GridView -PassThru

            #Specify UserID
            $script:userID = $adObject.SamAccountName
        }
    } while ($script:userID -eq $null)
}
write-host "Confirmed UserID is: $script:userID" -foregroundcolor green    
    

#Display user Info
Get-ADUser $script:userID -properties Name, SamAccountName, EmployeeType, office, Title, telephoneNumber, mobile, Manager, Enabled, LockedOut, lockoutTime, PasswordLastSet, LastBadPasswordAttempt, LastLogonDate, Modified  | 
Select-Object -Property Name, SamAccountName, EmployeeType, office, Title, telephoneNumber, mobile, Manager, Enabled, LockedOut, lockoutTime, PasswordLastSet, LastBadPasswordAttempt, LastLogonDate, Modified

#if account disabled > display msg and exit
$status = (Get-ADUser $script:userID -Properties LockedOut).LockedOut
if (!((Get-ADUser $script:userID -Properties LockedOut).Enabled)) {
    Write-Host "Account is disabled! " -ForegroundColor Red
    exit
}

Write-Progress "Checking If account is locked > prompt confirmation to proceed to Unlock"
if ($status) {
    Write-Host "$script:userID Status:Locked out!" -ForegroundColor Red
    Write-Host "Requesting confirmation to unlock. Look for pop up window for confirmation" -ForegroundColor Yellow
    #Prompt to Unlock account
        #Option Menu to proceed to rename folders
        #Add Menu options
        Add-Type -AssemblyName PresentationCore,PresentationFramework
        #Menu Variable
        $msgBoxInput =  [System.Windows.MessageBox]::Show('Would you like to Unlock user account?','Please confirm!','YesNo','Question')

        #Set Menu response
        switch  ($msgBoxInput) {
            'Yes' {
            Write-Progress "Unlocking account..."
            Get-ADUser $script:userID | Unlock-ADAccount
                    #Validate - Refresh status
                    $status = (Get-ADUser $script:userID -Properties LockedOut).LockedOut
                    if (!($status)) {
                        Write-Host "Confirmed Unlocked!" -ForegroundColor Green
                    } else {
                        Write-Host "Failed! Check cmd: 'net user /domain $script:userID' for more info!" -ForegroundColor Red
                    }
            }
            'No' {
                Write-Host "Ending Script..." -ForegroundColor Red
                exit
            }
        }
} else {
    Write-Host "$script:userID Account Status is normal!" -ForegroundColor Green
} #Improvement: Create ticket to ServiceNow 