$computerName = Read-Host "Computer Name"

#Get-ADUser $userName
$userName = (Get-CimInstance -ComputerName $computerName -ClassName Win32_ComputerSystem).UserName

#Split userName
$userName = $userName.Split('\')[1]

#Get user Info
$userName 
$name = (Get-ADUser $userName).Name 
$upn = (Get-ADUser $userName).UserPrincipalName
$manager = (get-aduser $userName -Properties manager).manager.split('=')[1].split('(')[0].replace('\,',',')

Write-Host "Name: $name"
Write-Host "UPN: $upn"
Write-Host "Manager: $manager"
