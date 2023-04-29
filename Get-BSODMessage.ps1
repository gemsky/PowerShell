$computerName = Read-Host 'Enter SAN number to get BSOD info from Event Log'
Write-Host 'Get-EventLog -LogName application -Newest 100 -Source 'Windows Error*' | select timewritten, message | ft -auto -wrap'

Invoke-Command -ScriptBlock { Get-EventLog -LogName application -Newest 100 -Source 'Windows Error*' | select timewritten, message | where message -match 'bluescreen' |  ft -auto -wrap } -ComputerName $computerName

Invoke-Command -ScriptBlock { Get-EventLog -LogName application -Newest 100 -Source 'Windows Error*' | select timewritten, message | ft -auto -wrap } -ComputerName $computerName


