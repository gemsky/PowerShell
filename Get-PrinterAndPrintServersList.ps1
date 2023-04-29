function Get-PrintServers {
    # List print server
    Get-ADObject -Filter 'objectClass -eq "printQueue"' -Properties ServerName |
        sort-object ServerName -Unique | Select-Object ServerName
} Get-PrintServers

function Get-PrintersList {
    # List Printers in AD
    Get-AdObject -filter "objectCategory -eq 'printqueue'" -Prop *|
        Select-object @{N='ShareNames';E={$_.printShareName -join ';'}},serverName |
            Sort-Object ShareNames    
}
Write-Host "Get-PrintServres and Get-PrintersList function enabled" -ForegroundColor "Green"