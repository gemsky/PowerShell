<#
.SYNOPSIS
    Set-PrintersWA connects a computer to a specified printer based on the closest print server.

.DESCRIPTION
    This script connects a computer to a specified printer based on the closest print server. It first determines the primary site based on the closest domain controller and then selects the appropriate print server based on the site name. If the print server supports the Follow-You Print service, it automatically connects to that printer. Otherwise, it prompts the user to select a printer from a list.

.PARAMETER None
    This script does not take any parameters.

.EXAMPLE
    Set-Printers
    This example runs the script and connects the computer to the appropriate printer.

.NOTES
    Author: Your Name
    Date:   Current Date
#>

#Execution policy
try{
    Set-ExecutionPolicy Bypass -Scope process -Force
} catch {
    clear-host
}
[System.Console]::Clear();
Clear-Host

function WriteHostDisplay ($message){
    Write-Host $message -ForegroundColor Yellow
    Write-Progress $message
    }

#Get Primary site by closest DC
        WriteHostDisplay "Get primary site"
        $location = (nltest /DSGETDC: | select-string "Dc Site Name") -split " "
        $siteName = $location[4]
        
#Print Server list:
    $printServer = switch ($siteName) {
    "NewYork"          { 'NYPRINT01' }
    "LosAngeles"       { 'LAPRINT01' }
    "Chicago"          { 'CHIPRINT01' }
    "Houston"          { 'HOUPRINT01' }
    "Phoenix"          { 'PHXPRINT01' }
    "Philadelphia"     { 'PHLPRINT01' }
    "SanAntonio"       { 'SAPRINT01' }
    "SanDiego"         { 'SDPRINT01' }
    "Dallas"           { 'DALPRINT01' }
    "SanJose"          { 'SJPRINT01' }
    "Austin"           { 'AUSPRINT01' }
    "Jacksonville"     { 'JAXPRINT01' }
    "SanFrancisco"     { 'SFPRINT01' }
    "Indianapolis"     { 'INPRINT01' }
    "Seattle"          { 'SEAPRINT01' }
    "Denver"           { 'DENPRINT01' }
    "Washington"       { 'DCPRINT01' }
    "Boston"           { 'BOSPRINT01' }
    "Nashville"        { 'NVPRINT01' }
    "Baltimore"        { 'BAPRINT01' }
    "OklahomaCity"     { 'OKCPRINT01' }
}
WriteHostDisplay "Confirmed closest print Server: $printServer"

#Connect Primary printer
#List of printers that has Follow-You Print service
Write-Progress "Check if Follow-You Print is available..."
$printServers = @('NYPRINT01','LAPRINT01','CHIPRINT01','HOUPRINT01','PHXPRINT01','PHLPRINT01')
if ($printServers -match $printServer) {
    try {
        Write-Progress "Confirmed Follow-You Print is available!"
        $connectionName = "\\$printServer.santos.com\Follow-You Print"
        WriteHostDisplay "Connecting to $connectionName"
        Add-Printer -ConnectionName $connectionName
        write-host "=======================================================" -ForegroundColor Yellow
        write-host "   Follow-You Print has been automatically connected." -ForegroundColor Green
        write-host "=======================================================" -ForegroundColor Yellow
        write-host " "
        write-host "=======================================================" -ForegroundColor Yellow
        WriteHostDisplay "Print service currently available on this computer: "
        write-host "=======================================================" -ForegroundColor Yellow
        Get-Printer  |select name |  ft -hide
        write-host "=======================================================" -ForegroundColor Yellow
    }
    catch {
        WriteHostDisplay "Error: Unable to connect to $connectionName"
    }
} else {
    #Select Printer
    Write-Progress "Select which printer your would like to connect to:"
    
    try {
    #Method 1 OutGridView
        $printerDetails = Get-Printer -ComputerName "$printServer.santos.com" | Out-GridView -Title "Select which printer your would like to connect to" -PassThru
        $printerName = $printerDetails.Name
    
    } catch {
    #Method 2 Manual Text
        write-host "=======================================================" -ForegroundColor Yellow
        write-host "             Printer List for $printServer :" -ForegroundColor Yellow
        write-host "=======================================================" -ForegroundColor Yellow
        (Get-Printer -ComputerName "$printServer.santos.com").Name
        write-host "=======================================================" -ForegroundColor Yellow
        $printerName = Read-Host "Copy and Paste desired printer name from list above (Make sure no spaces)"
    }
    WriteHostDisplay "Printer selected: $printerName"        

    #Connect PC to printer
    try {
        $connectionName = "\\$printServer.santos.com\$printerName"
        WriteHostDisplay "Connecting to $connectionName"
        Add-Printer -ConnectionName $connectionName
        WriteHostDisplay "$printerName has been connected successfully"
        write-host " "
        write-host "=======================================================" -ForegroundColor Yellow
        WriteHostDisplay "Print service currently available on this computer: "
        write-host "=======================================================" -ForegroundColor Yellow
        Get-Printer  |select name |  ft -hide
        write-host "=======================================================" -ForegroundColor Yellow
    } catch {
        WriteHostDisplay "Printer $Printerfullname not installed "
    }
}

#Option to add secondary Printer
WriteHostDisplay "Do you want to add a second network printer? (Y/N) "
$response = read-host
if ( $response -ne "N" ) { 
    #Select Printer
    Write-Progress "Select which printer your would like to connect to:"
    
    try {
    #Method 1 OutGridView
        $printerDetails = Get-Printer -ComputerName "$printServer.santos.com" | Out-GridView -Title "Select which printer your would like to connect to" -PassThru
        $printerName = $printerDetails.Name
    
    } catch {
    #Method 2 Manual Text
        write-host "=======================================================" -ForegroundColor Yellow
        write-host "             Printer List for $printServer :" -ForegroundColor Yellow
        write-host "=======================================================" -ForegroundColor Yellow
        (Get-Printer -ComputerName "$printServer.santos.com").Name
        write-host "=======================================================" -ForegroundColor Yellow
        $printerName = Read-Host "Copy and Paste desired printer name from list above (Make sure no spaces)"
    }
    WriteHostDisplay "Printer selected: $printerName"        

    #Connect PC to printer
    try {
        $connectionName = "\\$printServer.santos.com\$printerName"
        WriteHostDisplay "Connecting to $connectionName"
        Add-Printer -ConnectionName $connectionName
        Write-Host "$printerName has been connected successfully" -ForegroundColor Green
        write-host " "
        write-host "=======================================================" -ForegroundColor Yellow
        WriteHostDisplay "Print service currently available on this computer: "
        write-host "=======================================================" -ForegroundColor Yellow
        Get-Printer  |select name |  ft -hide
        write-host "=======================================================" -ForegroundColor Yellow
    } catch {
        WriteHostDisplay "Printer $Printerfullname not installed "
    }
}
Pause
