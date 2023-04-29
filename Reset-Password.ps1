#Reset Password Script
#Get user details
    #Validate module: consoleGuiTools
    #PSversion
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        if (!(Get-InstalledModule -name microsoft.powershell.ConsoleGuiTools)) {
        #Install GUI Tools
            Write-Progress "Installing Module"
            Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Force
            Import-Module -Name Microsoft.PowerShell.ConsoleGuiTools
        }  #Example: get-childitem | Out-ConsoleGridView

        #LookUp UserID
        do {
        #prompt for Name input following 'lastName, FirstName' format
        $Name = Read-Host "Enter User Display name (LastName, FirstName) to Look up UserID"

        #LookUp Relevant AD Account and display in consolegridview
        $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
            Select-Object Name, SamAccountName |
                Out-ConsoleGridView

        #Specify UserID
        $SamAccountName = $adObject.SamAccountName
        } while ($SamAccountName -eq $null)

    } else {
        #LookUp UserID
        do {
            #prompt for Name input following 'lastName, FirstName' format
            $Name = Read-Host "Enter User Display name (LastName, FirstName) to Look up UserID"
    
            #LookUp Relevant AD Account and display in consolegridview
            $adObject = Get-ADUser -Filter "displayName -like '$Name*'" |
                Select-Object Name, SamAccountName |
                    Out-GridView -PassThru
    
            #Specify UserID
            $SamAccountName = $adObject.SamAccountName
            } while ($SamAccountName -eq $null)
    }

#Check if account is active
$EnableStat = (get-aduser $SamAccountName).Enabled

Write-Progress "Checking Account status..."
if ($EnableStat) {
    Write-Host "Account is Active!" -ForegroundColor Green

        #Reset Password
        Set-ADAccountPassword -Identity $SamAccountName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "HappySummer22!" -Force)

        #Set 'Must change password at logon'
        Set-ADUser $SamAccountName -ChangePasswordAtLogon $true

        #Check if account is lockedout
        #$gaul = Get-ADUser $SamAccountName -Properties LockedOut
        $Lockstat = (Get-ADUser $SamAccountName).LockedOut

        write-host "Checking account locked status..." -ForegroundColor Yellow
        if ($Lockstat -eq "True") {
            Unlock-ADAccount $SamAccountName
            Write-Host "Account has been unlocked!" -ForegroundColor Green
        }else {
            Write-Host "Account is not locked!" -ForegroundColor Green
        }

        Write-Host "Password of userID $SamAccountName has been changes to HappySummer22!" 

} else {
    Write-Host "Account is Disabled! Ending Script..." - -ForegroundColor Red
}