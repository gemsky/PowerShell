#Repair OneDrive - Need to be triggered by user
#Source: https://support.microsoft.com/en-us/office/reset-onedrive-34701e00-bf7b-42db-b960-84905399050c

#Reset Windows Store cache
Start-Process "wsreset.exe"
Start-Sleep -Seconds 5
Get-Process -ProcessName "WinStore.App" | Stop-Process

#Reset OneDrive Client

%localappdata%\Microsoft\OneDrive\onedrive.exe
if (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\onedrive.exe") {
    Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\onedrive.exe" -ArgumentList " /reset"
} elseif (Test-Path "C:\Program Files\Microsoft OneDrive\onedrive.exe") {
    Start-Process "C:\Program Files\Microsoft OneDrive\onedrive.exe" -ArgumentList " /reset"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft OneDrive\onedrive.exe") {
    Start-Process "C:\Program Files (x86)\Microsoft OneDrive\onedrive.exe" -ArgumentList " /reset"
} else {
    Write-Warning "OneDrive.exe not found!"
}