#Title: BrowserClearChaceLog
$computerName = Read-Host "Enter users computer SAN number"

$userName = Read-Host "Enter customer 5 character userID"

Invoke-Command -ComputerName $computerName -ArgumentList $userName -ScriptBlock {
#Log file Function to Display in host, progress bar and logs
    #check else Create file name
    $date = Get-date -Format ddMMyy
    $copyLog = "BrowserClearChaceLog"+$using:userName+$date+".log"
    $logfilepath = "C:\Temp\$CopyLog"

    function WriteHostDisplayAndLogFile ($message){
    Write-Host $message -ForegroundColor Yellow
    Write-Progress $message
    (Get-Date).ToString() + " " + $message  >> $logfilepath
    }
    WriteHostDisplayAndLogFile " Starting Browser Cache clear..."
    
    WriteHostDisplayAndLogFile "Clear browser data"
    WriteHostDisplayAndLogFile "Clear Chrome data - kill browser process"
    #source: https://forum.uipath.com/t/clear-cache-in-chrome-powershell-or-cmd-prompt/195110
    if (Get-Process -Name "chrome" -ErrorAction SilentlyContinue) {
        taskkill /F /IM "chrome.exe"
        Start-Sleep -Seconds 5
    } 

    $Items = @('Cache\*',
                '*Cookies*',
                'Network\cookies*',
                'Log*'
                )
    #Get default and additional profile folders
    $profiles = (Get-ChildItem -Path "C:\Users\$using:userName\AppData\Local\Google\Chrome\User Data\" | Where-Object {($_.Name -like 'Default') -or ($_.Name -like 'Profile*')}).Name

    WriteHostDisplayAndLogFile "Clear data from all Chrome profiles"
    $profiles | ForEach-Object {
        $path = "C:\Users\$using:userName\AppData\Local\Google\Chrome\User Data\$_\"
        $Items | ForEach-Object { 
            if (Test-Path "$path\$_") {
                Remove-Item "$path\$_" -Recurse -Force -Confirm:$false
                WriteHostDisplayAndLogFile "Succesfully cleared Chrome browsing data"
            }
        }
    }

    WriteHostDisplayAndLogFile "Clear Microsoft Edge data - kill browser process"
    #Source: https://www.reddit.com/r/PowerShell/comments/npl04q/help_me_to_optimize_my_clear_cache_edge_browser_ps/
    if (Get-Process -Name MsEdge -ErrorAction SilentlyContinue) {
        taskkill /F /IM "msedge.exe"
        Start-Sleep -Seconds 5
    }
    
    $items = @(
        'Cache\*',
        'Network\cookies*',
        'Log*'
        )
    
    $profiles = (Get-ChildItem -Path "C:\Users\$using:UserName\AppData\Local\Microsoft\Edge\User Data\" | Where-Object {($_.Name -like 'Default') -or ($_.Name -like 'Profile*')}).Name
    
    WriteHostDisplayAndLogFile "Clear data from all Edge profiles"
    $profiles | ForEach-Object {
        $Path = "C:\Users\$using:UserName\AppData\Local\Microsoft\Edge\User Data\$_\"
        $items | ForEach-Object {
            if (Test-Path "$path\$_") {
                Remove-Item -path "$path\$_"  -Recurse -Force -Confirm:$false
                WriteHostDisplayAndLogFile "Succesfully cleared Edge browsing data"
            }
        }
    }
}