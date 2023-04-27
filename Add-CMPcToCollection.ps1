function CMaddPcToCollection {
[CmdletBinding()]
param (
    [Parameter(
        Mandatory=$true,
        Position=0
    )]
    [String]
    $ComputerName,
    [Parameter(
        Mandatory=$true,
        Position=1
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
        Write-Progress "Confirmed connection to CM Drive"
    } else {
        Write-Progress "Not connected to CM Drive - connecting..."
        
        #connect to CM Drive
        $SiteCode = Get-PSDrive -PSProvider CMSITE
            Set-Location -Path "$($SiteCode.Name):\"
    }

    #Search app in CCM
    #$ComputerName = Read-Host "Enter SanNumber name to add to collection"
    #$appkeyword = Read-Host "Enter App keyword to search CCM collection"
    Write-Progress "Searching app..."
    $app = (Get-CMCollection -name "*$appkeyword*" | Sort-Object -Property Name).Name | Out-GridView -PassThru
    Write-Host "Confirmed app selected is: $app "
    $gCCM = (Get-CMCollectionMember -collectionName $app).Name

    if ($ComputerName -in  $gCCM) {
        Write-Warning "Computer already member of the collection! Ending Script!"

    } else {
        try {
            Add-CMDeviceCollectionDirectMembershipRule -CollectionName $app -resourceID (get-cmdevice -Name $ComputerName).ResourceID

            #Run CCM action items on client - Requires computer to be online
            function RunCMActionItemsRemotly {
                <#
            .SYNOPSIS
            Run Software Center Configuration Manager client action items remotely
            .DESCRIPTION
            This script will connect to the computer and trigger CM Actions items on client machine
            Requirement: Computer is Online.
            .PARAMETER ComputerName
            $computerName
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
                    $ComputerName
                )
                #Run CCM action items on client - Requires computer to be online
                if (Test-Connection -ComputerName $ComputerName -Quiet -count 1) {
                    Write-Host "Computer Online! " -ForegroundColor Green
                    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
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
            
                Write-Host "CCM Action items has been activated remotely!" -ForegroundColor Green     
                } else {
                Write-Host "$ComputerName is currently offline!" -ForegroundColor Red
                }
            } RunCMActionItemsRemotly $ComputerName
            Write-Host "Confirmed membership!"
            Write-Host "Successfully added $ComputerName to collection $app. Please give up to 24 hours for installation to download and complete. Note: Santos Network/VPN connection required." -ForegroundColor Green 
        }
        catch {
            Throw
        }
    }

    #End Script by returning to original drive location
    #if connected to CM Drive - Reverse Connection!
    if ((Get-Location).Path -eq "ADE:\") {
        Set-Location -path $curLoc
    }     
} CMaddPcToCollection