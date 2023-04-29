#Check Accounts about to expire
$expiringAccounts =  Search-ADAccount -AccountExpiring -TimeSpan "7" -UsersOnly | 
    Where-Object {$_.Enabled -eq $True} |
        Sort-Object Name |
            Select-Object SamAccountName
