$ComputerName = Read-Host "Enter Computer SAN# Name to kill MSRA process"

#check if ComputerName is online
if (Test-Connection -ComputerName $ComputerName -Count 1 -quiet) {
    Write-Host "$ComputerName is Online!" -ForegroundColor Green
        
    invoke-command $ComputerName {
    #if msra running Kill it
    $msra = get-process msra
    if ($msra){
        Write-Progress "Stopping MSRA process..."
        $msra | Stop-Process -Force
    } else {
        Write-Host "No MSRA process running, ending script" -ForegroundColor red
    }
    }

} else {
    Write-Host "$ComputerName is currently Offline Or unreachable - ending script!" -ForegroundColor Red
    exit
}