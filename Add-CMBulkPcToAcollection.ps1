function CMaddBulkPcToAcollection {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$true,
            Position=0
        )]
        [String]
        $appkeyword
    )

    #Script to add PC to a  CCM app collection
    #check CM module
    if ((Get-Module -Name "ConfigurationManager").Name) {
        
    } else {
        Write-Warning "No CCM module installed - improting!"
        Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
    }
    
    #check connection
    #Save current connection
    $curLoc = (Get-Location).Path
    
    #if no connected to CM Drive - Connect!
    if ((Get-Location).Path -eq "ADE:\") {
        Write-Host "Confirmed connection to CM Drive" -ForegroundColor Green
    } else {
        Write-Warning "Not connected to CM Drive - connecting..."
        
        #connect to CM Drive
        $SiteCode = Get-PSDrive -PSProvider CMSITE
            Set-Location -Path "$($SiteCode.Name):\"
    }
    
    #Update Computer Names to Text file
        #Open Text file to enter hostnames
        $path = "C:\Temp\"
        $fileName = "pcNames.txt"
        $filePath = $path+$fileName
        if (!(Test-Path $filePath)) {
            New-Item -Path $path -Name $fileName -ItemType "file"
        }
        Start-Process Notepad.exe $filePath
        Write-Host "Enter 'Device Collections' names in to Notepad that just opened, then Save changes and close it for connection test to proceed"
        Write-Host "Make sure all open Notepads are closed, for process to proceed" -foregroundcolor Red

        #Get Notepad Process
        $nid = (Get-Process notepad).Id

        #Wait for Notepad to close
        Wait-Process -Id $nid

        #Add App Collection to variable
        $pcList = Get-Content $filePath

        #Search app in CCM
        Write-Progress "Searching app..."
        do {
            $app = (Get-CMCollection -name "*$appkeyword*" | Sort-Object -Property Name).Name | Out-GridView -PassThru    
        } while ( $null -eq $app )
        
        Write-Host "Confirmed app selected is: $app " -ForegroundColor Green
        $gCCM = (Get-CMCollectionMember -collectionName $app).Name

        #Validate Pcs exist
        $goodPcs = @()
        $badPcs = @()
        Write-Progress "Validating Pcs in SCCM..."
        foreach($pc in $pcList){
            $validatePc = Get-CMDevice -Name $pc
            if ($validatePc) {
                $goodPcs += $pc
            } else {
                $badPcs += $pc
            }
        }
        if (($badPcs.count -gt 0) ) {
            Write-Host "============================" -ForegroundColor Yellow
            Write-Warning "These Pcs DONT exist in SCCM:"
            Write-Host "============================" -ForegroundColor Yellow
            $badPcs
            Write-Host "============================" -ForegroundColor Yellow
            Write-Host ""
        }
    
    foreach ($pc in $goodPcs) {
    #Validate if pc is already member of App collection
        if ($pc -in  $gCCM) {
            Write-Warning "$pc already member of the collection!"
        } else {
            try {
                Write-Progress "Adding $pc to $app"
                Add-CMDeviceCollectionDirectMembershipRule -CollectionName $app -resourceID (get-cmdevice -Name $pc).ResourceID  
                Write-Host "Successfully added $pc to $app"              
            }
            catch {
                Write-Warning "Failed to add $pc to $app collection"
            }  
        }
    }

    #Run CM actions on all good pcs
    foreach ($pc in $goodPcs) {
        function RunCMActionItemsRemotly {
            <#
        .SYNOPSIS
        Run Software Center Configuration Manager client action items remotely
        .DESCRIPTION
        This script will connect to the computer and trigger CM Actions items on client machine
        Requirement: Computer is Online.
        .PARAMETER ComputerName
        $pc
        .INPUTS
        System.String.
        .OUTPUTS
        List of Updates Date and title
        .EXAMPLE
        Currently designed to be ran from an existing powershell console:
        Change directory to Where the file is saved on local HDD (usualy:) cd C:\Script\
        type first few letters of script name at PS prompt, and use tab to auto complete
        .\Run-CMActionItemsRemotly.ps1
        
        .EXAMPLE
        Open Powershell console
        Load function:
        . .\Run-CMActionItemsRemotly.ps1
        Then type RunCMActionItemsRemotly to call the function.
        Enter computer Name
        
        Note: you only need to load once, and the function will be available for that console session
        #>
        [CmdletBinding(SupportsShouldProcess=$true)]
            param (
                [Parameter(Mandatory =$true)]
                [String]
                $pc
            )
            #Run CCM action items on client - Requires computer to be online
            if (Test-Connection -ComputerName $pc -Quiet -count 1) {
                Write-Progress "Computer Online! "
                Invoke-Command -ComputerName $pc -ScriptBlock {
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000121}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000003}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000010}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000002}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000031}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000111}"
                    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000032}"
                } -AsJob | Out-Null
        
            Write-Progress "$pc - CCM Action items has been triggered remotely!"
            } else {
            Write-Host "$pc is currently offline!" -ForegroundColor Red
            }
        } RunCMActionItemsRemotly $pc
    }
    
    #End Script by returning to original drive location
    #if connected to CM Drive - Reverse Connection!
    if ((Get-Location).Path -eq "ADE:\") {
        Set-Location -path $curLoc
    } 
    
} CMaddBulkPcToAcollection