#Title: Reset Outlook profile
#Log file Function to Display in host, progress bar and logs
    #check else Create file name
    $date = Get-date -Format ddMMyy
    $copyLog = "OutlookProfileResetLog"+$username+$date+".log"
    $logfilepath = "C:\Temp\$CopyLog"

    function WriteHostDisplayAndLogFile ($message){
    Write-Host $message 
    Write-Progress $message
    (Get-Date).ToString() + " " + $message  >> $logfilepath
    }

WriteHostDisplayAndLogFile "Reset user Outlook profile script for Office 365" 

#Confirmation GUI
Add-Type -AssemblyName PresentationFramework
$msgBoxInput = [System.Windows.MessageBox]::Show(
    'Are you sure you would like to proceed to RESET your Outlook profile? If Yes, please do not re-open Outlook until process is finish.',
    'Please confirm!',
    'YesNo',
    'warning'
    )

switch  ($msgBoxInput) {
    'Yes' {
        #Kill Outlook Process
        WriteHostDisplayAndLogFile "Kill Office related Process"
        if (Get-Process outlook -ErrorAction SilentlyContinue) {
            Get-Process outlook | Stop-Process | Out-Null
        } 

        #Kill Skype Process
        if (Get-Process Lync -ErrorAction SilentlyContinue) {
            Get-Process Lync | Stop-Process | Out-Null
        }

        #Kill Teams Process
        if (Get-Process Teams -ErrorAction SilentlyContinue) {
            Get-Process Teams | Stop-Process | Out-Null
        }

        #Kill ucmapi Process
        if (Get-Process ucmapi -ErrorAction SilentlyContinue) {
            Get-Process ucmapi | Stop-Process | Out-Null
        }

        #Give time for process to terminate
        Start-sleep -Seconds 5

        #ReName Outlook Roaming profile folder
        $newOldProfileName = (get-date).ToString("yyyyMMddhhmm")
        $NewName = "Outlook.old"+$newOldProfileName
        WriteHostDisplayAndLogFile "Reset Roaming profile folder"
        if (Test-Path "$Env:appdata\Microsoft\Outlook\") {
            Try {
                Rename-Item "$Env:appdata\Microsoft\Outlook\" -NewName $NewName -force  | Out-Null
            } Catch {
                WriteHostDisplayAndLogFile throw
                $msgBoxInput = [System.Windows.MessageBox]::Show(
                'Profile folder rename FAILED! Restart your computer and Try again. If still fails: Contact EUC analyst for manual profile reset! Restart Now?',
                'Outlook Profile Reset: FAILED!',
                'YesNo',
                'Error'
                )
                switch  ($msgBoxInput) {
                    'Yes' {
                        WriteHostDisplayAndLogFile "Restarting Computer!"
                        shutdown -r -f -t 01
                    }
                    
                    'No' {
        
                        Exit
                
                    }
                } 
            }
        }

        #ReName Outlook Local Profile folder
        WriteHostDisplayAndLogFile "Reset Local profile folder"
        if (Test-Path "$env:LOCALAPPDATA\Microsoft\Outlook\") {
            Try {
                Rename-Item "$env:LOCALAPPDATA\Microsoft\Outlook\" -NewName $NewName -force  | Out-Null
            } Catch {
                WriteHostDisplayAndLogFile throw
                $msgBoxInput = [System.Windows.MessageBox]::Show(
                'Profile folder rename FAILED! Restart your computer and Try again. If still fails: Contact EUC analyst for manual profile reset! Restart Now?',
                'Outlook Profile Reset: FAILED!',
                'YesNo',
                'Error'
                )
                switch  ($msgBoxInput) {
                    'Yes' {
                        WriteHostDisplayAndLogFile "Restarting Computer!"
                        shutdown -r -f -t 01
                    }
                    
                    'No' {
        
                        Exit
                
                    }
                } 
            }
        }

        Write-Progress "Validate Profile folder rename was succesful:"
        if (!(Test-Path "$env:LOCALAPPDATA\Microsoft\$NewName")) {
            WriteHostDisplayAndLogFile "Rename profile folder failed!"
                $msgBoxInput = [System.Windows.MessageBox]::Show(
                'Profile folder rename FAILED! Restart your computer and Try again. If still fails: Contact EUC analyst for manual profile reset! Restart Now?',
                'Outlook Profile Reset: FAILED!',
                'YesNo',
                'Error'
                )
                switch  ($msgBoxInput) {
                    'Yes' {
                        WriteHostDisplayAndLogFile "Restarting Computer!"
                        shutdown -r -f -t 01
                    }
                    
                    'No' {
        
                        Exit
                
                    }
                } 
        }

        #Control Panel:Mail32: Profile
        # Start-Process "C:\Program Files (x86)\Microsoft Office\root\Office16\MLCFG32.CPL"
        #Get current profile name
        $oldProfileName = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook' -Name 'DefaultProfile').DefaultProfile
        WriteHostDisplayAndLogFile "Current Profile Name is: $oldProfileName" 

        #Rename Old Control Panel:Mail32: Profile
        WriteHostDisplayAndLogFile "ReName Control Panel:Mail32: Profile"
        if (Test-Path "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\Outlook") {
            WriteHostDisplayAndLogFile "Reset CP Profile"
                #Remove-Item -path "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\*" -Recurse -Force | Out-Null
                #Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Office\16.0\Outlook\Setup\" -name First-Run | Out-Null

            #ReName Profile 
            WriteHostDisplayAndLogFile "Default Profile name: Outlook detected - Renaming!"
            $newOldProfileName = (get-date).ToString("yyyyMMddhhmm")
            Rename-Item -path "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\Outlook" -NewName $newOldProfileName -Force  | Out-Null
        }

        <#Delete All old CP Profiles:
        $reg="HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles"
        $child=(Get-ChildItem -Path $reg).name
        foreach($item in $child){
            try{
                Write-Progress "Removing Outlook registry profiles"
                Remove-item -Path registry::$item -Recurse #-ErrorAction Inquire -WhatIf
                Write-Progress "$item profiles removed successfully"
            }catch{
                throw
            }
        } #>

        #Create New Control Panel:Mail32: Profile
        WriteHostDisplayAndLogFile "Create New Control Panel:Mail32: Profile"
        if (Test-Path "HKCU:\Software\Microsoft\Office\16.0\Outlook") {
            #Create new Profile
            WriteHostDisplayAndLogFile "Create new Profile"
            $NewProfileName = "Outlook"
            Try { 
                New-Item -Name $NewProfileName -Path "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles\" -Force -Verbose 
            } Catch { 
                WriteHostDisplayAndLogFile $Error[0].Exception.Message 
            } 
            
            
            #Set Default Profile
            WriteHostDisplayAndLogFile "Set Default Profile"
            Try { 
                Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook' -Name 'DefaultProfile' -Value $NewProfileName 
            } Catch { 
                WriteHostDisplayAndLogFile $Error[0].Exception.Message 
            }

        } else {
            WriteHostDisplayAndLogFile "Office 365 registry not detected - confirm Office version"
        }

        #Clear Credential manager:
        cmdkey /list | ForEach-Object{if($_ -like "*Target:*"){cmdkey /del:($_ -replace " ","" -replace "Target:","")}}

        WriteHostDisplayAndLogFile "Registry Updated! Restart computer for changes to take effect"
        WriteHostDisplayAndLogFile "After restart, Start Outlook app, it make take sometime"
        $msgBoxInput = [System.Windows.MessageBox]::Show(
            'Outlook Profile Reset completed, Restart computer for changes to take effect. Restart now?',
            'Outlook Profile Reset: Finish - Restart required!',
            'YesNo',
            'warning'
            )

        switch  ($msgBoxInput) {
            'Yes' {
                WriteHostDisplayAndLogFile "Restarting Computer!"
                shutdown -r -f -t 01
            }
            
            'No' {

                Exit
        
            }
        }
    }
    'No' {

        Exit

    }
}