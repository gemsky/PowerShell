$computerName = Read-Host "Enter SAN number or ComputerName to get Installed app list"
    if (Test-Connection $computerName -Quiet -Count 1) {
        Write-Host "$computerName is Online!" -ForegroundColor Green
        Write-Host "Getting Instalation info..." -ForegroundColor Yellow

        Invoke-Command -ComputerName $computerName -ScriptBlock {
            Write-Host "32Bit apps " -ForegroundColor Yellow
            $32bitapps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* 
            $32bitapps | select DisplayName,DisplayVersion,InstallDate | Sort-Object InstallDate  | Select-Object -Last 10 | FT
            
            Write-Host "64Bit apps " -ForegroundColor Yellow
            $64bitapps = Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            $64bitapps | select DisplayName,DisplayVersion,InstallDate | Sort-Object InstallDate  | Select-Object -Last 10 | FT


        }
        
        write-host "CimInstance Apps" -ForegroundColor Yellow
        Get-CimInstance -ComputerName $computerName -ClassName win32_product -ErrorAction SilentlyContinue |
            Select-Object Name,Version,InstallDate | Sort-Object InstallDate | Select-Object -Last 10 | FT
    }