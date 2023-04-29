#Update Computer Names to Text file
    #Open Text file to enter hostnames
    $path = "C:\Temp\"
    $fileName = "pcNames.txt"
    $filePath = $path+$fileName
    if (!(Test-Path $filePath)) {
        Write-Progress "Create file to store data..."
        New-Item -Path $path -Name $fileName -ItemType "file"
    }
    C:\Temp\pcNames.txt
    Write-Progress "Enter 'Device Collections' names in to Notepad that just opened, then Save changes and close it for connection test to proceed"
    Write-host "Make sure all open Notepads are closed, for process to proceed" -foregroundcolor Red

    #Get Notepad Process
    $nid = (Get-Process notepad).Id

    #Wait for Notepad to close
    Wait-Process -Id $nid

    #Add App Collection to variable
    Write-Progress "Getting content $filePath..."
    $pcNames = Get-Content $filePath

#Validate Log file
    $logPath = "C:\Temp\winverLog.txt"
    if (Test-Path $logPath) {
        Clear-Content $logPath
    } else {
        New-Item $logPath
    }

foreach($computerName in $pcNames){
    Write-Progress "Validating $computerName ..."
    $testCon = Test-Connection $computerName -Count 1 -ErrorAction SilentlyContinue
    if ($testCon) {
        #WindowsVersion
        $Winver = Invoke-Command -ScriptBlock { 
            (Get-ComputerInfo).WindowsVersion
        } -ComputerName $computerName

        $log = [String]"$computerName>$Winver" 
        $log >> $logPath
        Write-Host "$log" -ForegroundColor Green
        
    } else {
        $log = [String]"$computerName>Offline" 
        $log >> $logPath
        Write-Host "$log" -ForegroundColor Green
    }

}

Write-Host "Get results in: $logPath"