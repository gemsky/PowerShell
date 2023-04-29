function Stop-Win11OSUpgrade {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]
        $runLocal
    )

<#
.DESCRIPTION
Until requirements are met for devices to upgrade to Windows 11, all devices will need to stay on Windows 10 for service and performance consistency.
This PowerShell script is designed to modify registry to prevent the Update.

.EXAMPLE
Example 1: Stop-Win11OSUpgrade
This will run the script for remote computers in bulk

Example 2: Stop-Win11OSUpgrade -runLocal
This will run the script locally, directly on the computer

#>
# Set execution policy to RemoteSigned
try {
    Set-ExecutionPolicy -ExecutionPolicy bypass -Scope Process -Force    
}
catch {}
function LogFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $message,
        [Parameter(Mandatory=$false, Position=1)]
        [switch]$Warning
    )
    #Validate Log file
    $global:logPath = "C:\Temp\NJDD.Log"
    if (!(Test-Path $logPath)) {
        New-Item $logPath -ItemType File -Force
    }
    if ($Warning) {
        Write-Warning $message
        Write-Progress $message
        [String]"$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $message" | out-file -FilePath $logPath -Append    <# Action to perform if the condition is true #>
    } else {
        Write-Host $message -f Green
        Write-Progress $message
        [String]"$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $message" | out-file -FilePath $logPath -Append    <# Action when all if and elseif conditions are false #>
    }
    
    }

if ($runLocal) {
    LogFunction "Running script locally"
    
        #Confirm if device is a server, if Yes then exit script
        LogFunction "Checking if device is a server"
        if ((Get-WmiObject -Class Win32_OperatingSystem).ProductType -eq 3) {
            LogFunction "This is a server, script will not run on a server" -Warning
            return
        }
        function Set-NewRegistryKeyvalue {
            param (
                [Parameter(Mandatory=$true)]
                [string]$path,
                [Parameter(Mandatory=$true)]
                [string]$name,
                [Parameter(Mandatory=$true)]
                [string]$value
            )
            #Confirm registry key exists
        if (!(Get-ItemProperty -Path $path -Name $name -ErrorAction silentlycontinue)) {
            try {    
            # Create new key
            New-Item -Path $path -Name $name -Force
            Set-ItemProperty -Path $path -Name $name -Value $value
            Write-Host "Created new registry key: $path\$name value: $value" -f Green
            } catch {
                Write-Host "Failed to create registry key: $path\$name value: $value" -f Red
                Write-Host $_.Exception.Message -f Red
            }
        } else {
            # Get current value of policy
            $keyValue = Get-ItemProperty -Path $path -Name $name | Select-Object -ExpandProperty $name
            if ($keyValue -ne $value) {
                try {
                    # Set value of key
                    Set-ItemProperty -Path $path -Name $name -Value $value
                    Write-Host "Created new registry key: $path\$name value: $value" -f Green
                }
                catch {
                    Write-Host "Failed to create registry key: $path\$name value: $value" -f Red
                    Write-Host $_.Exception.Message -f Red
                }
            } else {
                Write-Host "Registry key already exists: $path\$name with value: $value" -f Green
            }   
        }
        }
            
            #variables
            $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            $name = "TargetReleaseVersion"
            $value = "1"
            Set-NewRegistryKeyvalue -path $path -name $name -value $value
            
            $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            $name = "TargetReleaseVersionInfo"
            $value ="22H2"
            Set-NewRegistryKeyvalue -path $path -name $name -value $value

            $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            $name = "ProductVersion"
            $value = "10"
            Set-NewRegistryKeyvalue -path $path -name $name -value $value
            
            # Restart computer
            LogFunction "Restarting computer"
            try {
                $restartTime = (Get-Date).AddDays(1).Date.AddHours(2)
                $taskName = "RTRestartComputerStopWin11Update"
                $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /t 0"
                $trigger = New-ScheduledTaskTrigger -Once -At $restartTime
                $settings = New-ScheduledTaskSettingsSet
                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User SYSTEM
                LogFunction "Computer will restart at $restartTime"    
            }
            catch {
                try {
                    #if: No Mapping Between Account Names And Security IDs Was Done
                    $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{827D319E-6EAC-11D2-A4EA-00C04F79F83A}"
                    $name = "ExtensionDebugLevel"
                    $value = "2"
                    Set-NewRegistryKeyvalue -path $path -name $name -value $value
                    shutdown /r /t 36000 /c "Windows Update has been applied, Restarting computer in 10 hours" /f /d p:4:2
                    LogFunction "Computer will restart in 10 hours"
            
                }
                catch {
                    LogFunction "Failed to restart computer" -f Red
                    LogFunction $_.Exception.Message -f Red        
                }
            }    
            LogFunction "Stop Windows 11 OS upgrade solution applied - Script completed"              
} else {
    #Get ComputerNames manual from user input
    LogFunction "Create Notepad file in C:\Temp folder called computerNames.txt"
    $filePath = "C:\Temp\computerNames.txt"
    #check if file exists:
    if (!(Test-Path $filePath)) {
        New-Item -ItemType File -Path $filePath -Force
    }

    #Open notepad and enter computer names:
    [String]"Delete this text and replace with list of computer Names." | Out-File -FilePath $filePath
    Start-Process -FilePath "notepad.exe" -ArgumentList $filePath | Get-Process

    LogFunction "Enter Computer names in to Notepad that just opened, then Save changes and close it for script to proceed"
    LogFunction "Make sure all open Notepads are closed, for process to proceed"

    #Get Notepad Process
    $nid = (Get-Process notepad).Id

    #Wait for Notepad to close
    Wait-Process -Id $nid

    #Create file with computer names:
    $computerNames = Get-Content $filePath
    $computerNames | foreach {
        #confirm if computer is online
        if (Test-Connection -ComputerName $_ -Count 1 -Quiet) {
            LogFunction "Computer $_ is online"
            #Run script on remote computer
            Invoke-Command -ComputerName $_ -ScriptBlock {
                function LogFunction {
                    [CmdletBinding()]
                    param (
                        [Parameter(Mandatory=$true, Position=0)]
                        [string]
                        $message,
                        [Parameter(Mandatory=$false, Position=1)]
                        [switch]$Warning
                    )
                    #Validate Log file
                    $global:logPath = "C:\Temp\NJDD.Log"
                    if (!(Test-Path $logPath)) {
                        New-Item $logPath -ItemType File -Force
                    }
                    if ($Warning) {
                        Write-Warning $message
                        Write-Progress $message
                        [String]"$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $message" | out-file -FilePath $logPath -Append    <# Action to perform if the condition is true #>
                    } else {
                        Write-Host $message -f Green
                        Write-Progress $message
                        [String]"$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $message" | out-file -FilePath $logPath -Append    <# Action when all if and elseif conditions are false #>
                    }
                    
                    }
                LogFunction "Running script on $($_)"
                
                #Function to create new registry key
                function Set-NewRegistryKeyvalue {
                    param (
                        [Parameter(Mandatory=$true)]
                        [string]$path,
                        [Parameter(Mandatory=$true)]
                        [string]$name,
                        [Parameter(Mandatory=$true)]
                        [string]$value
                    )
                    #Confirm registry key exists
                if (!(Get-ItemProperty -Path $path -Name $name -ErrorAction silentlycontinue)) {
                    try {    
                    # Create new key
                    New-Item -Path $path -Name $name -Force
                    Set-ItemProperty -Path $path -Name $name -Value $value
                    Write-Host "Created new registry key: $path\$name value: $value" -f Green
                    } catch {
                        Write-Host "Failed to create registry key: $path\$name value: $value" -f Red
                        Write-Host $_.Exception.Message -f Red
                    }
                } else {
                    # Get current value of policy
                    $keyValue = Get-ItemProperty -Path $path -Name $name | Select-Object -ExpandProperty $name
                    if ($keyValue -ne $value) {
                        try {
                            # Set value of key
                            Set-ItemProperty -Path $path -Name $name -Value $value
                            Write-Host "Created new registry key: $path\$name value: $value" -f Green
                        }
                        catch {
                            Write-Host "Failed to create registry key: $path\$name value: $value" -f Red
                            Write-Host $_.Exception.Message -f Red
                        }
                    } else {
                        Write-Host "Registry key already exists: $path\$name with value: $value" -f Green
                    }   
                }
                }
                        
                #variables
                $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
                $name = "TargetReleaseVersion"
                $value = "1"
                Set-NewRegistryKeyvalue -path $path -name $name -value $value

                $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
                $name = "TargetReleaseVersionInfo"
                $value ="22H2"
                Set-NewRegistryKeyvalue -path $path -name $name -value $value

                $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
                $name = "ProductVersion"
                $value = "10"
                Set-NewRegistryKeyvalue -path $path -name $name -value $value
                
                # Restart computer
                LogFunction "Creating restart scheduled task"
                try {
                    $restartTime = (Get-Date).AddDays(1).Date.AddHours(2)
                    $taskName = "RTRestartComputerStopWin11Update"
                    $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /t 0"
                    $trigger = New-ScheduledTaskTrigger -Once -At $restartTime
                    $settings = New-ScheduledTaskSettingsSet                    
                    $TaskPath = "\"

                    # Check if task already exists
                    if (Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue) {
                        # If task exists, remove it
                        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
                    }

                    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User SYSTEM
                    LogFunction "Computer will restart at $restartTime"    
                } catch {
                    try {
                        #if: No Mapping Between Account Names And Security IDs Was Done
                        $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{827D319E-6EAC-11D2-A4EA-00C04F79F83A}"
                        $name = "ExtensionDebugLevel"
                        $value = "2"
                        Set-NewRegistryKeyvalue -path $path -name $name -value $value
                        shutdown /r /t 36000 /c "Windows Update has been applied, Restarting computer in 10 hours" /f /d p:4:2
                        LogFunction "Computer will restart in 10 hours"
                
                    }
                    catch {
                        LogFunction "Failed to restart computer"  -Warning
                        LogFunction $_.Exception.Message          
                    }
                }    
                LogFunction "Stop Windows 11 OS upgrade solution applied - Script completed"
            }
        } else {
            LogFunction "Computer $_ is offline" -Warning
        } #end if device is Online
    } #end foreach
}
} #end function