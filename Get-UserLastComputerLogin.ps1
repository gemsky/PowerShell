$ComputerName = Read-Host "Enter Computer Name to see last login"
Get-ADComputer $ComputerName -Properties lastlogontimestamp | 
    Select-Object @{n="Computer";e={$_.Name}}, @{Name="Lastlogon"; Expression={[DateTime]::FromFileTime($_.lastLogonTimestamp)}}
