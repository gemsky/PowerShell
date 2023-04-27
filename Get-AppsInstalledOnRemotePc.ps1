$SanNumber = Read-Host "Enter SAN number to get installed app status"
    if (Test-Connection $SanNumber -Quiet -Count 1) {
        Write-Host "$SanNumber is Online!" -ForegroundColor Green
        Invoke-Command -ComputerName $SanNumber -ScriptBlock {
            Get-CimInstance -ClassName CCM_Application -Namespace "root\ccm\clientSDK"  | 
                Sort-Object  name | 
                    Format-Table InstallState, name 
                } 
    } else {
        Write-Host "$SanNumber is Offline!" -ForegroundColor Red
    }