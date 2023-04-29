$computerName = Read-Host "Enter SAN number or ComputerName to Uninstall from"
$AppName = Read-Host "Enter App name to Uninstall"
Get-CimInstance -ComputerName $computerName -ClassName win32_product -ErrorAction SilentlyContinue | 
    Where-Object {$_.name -match $AppName} |
        Sort-Object -Property IdentifyingNumber |
            ft name,version,IdentifyingNumber
            
$IdentifyingNumber = Read-Host "CopyPaste App IdentifyingNumber to get app Uninstalled"
(Get-WmiObject Win32_Product -ComputerName $computerName | Where-Object {$_.IdentifyingNumber -eq $IdentifyingNumber}).Uninstall()

Get-CimInstance -ComputerName $computerName -ClassName win32_product -ErrorAction SilentlyContinue | 
    Select-Object Name, IdentifyingNumber, version | FT Name
Write-Host -nonewline "Successfully Uninstalled $IdentifyingNumber from $computerName"
Write-Host "(Get-WmiObject Win32_Product -ComputerName $computerName | Where-Object {$_.IdentifyingNumber -eq $IdentifyingNumber}).Uninstall()"


