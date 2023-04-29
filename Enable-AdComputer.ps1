#ReEnable a computer ad account
function Enable-AdComputerAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        Position = 0,
        ValueFromPipeline=$true)]
        [String]
        $computerName
    )

    Write-Progress "Getting computer info"
    $PcInfo = Get-ADComputer -Identity $computerName -Properties description
    $PcStatus = $PcInfo.Enabled

    #Check status
    if ($PcStatus -eq $false) {
        Write-host "Confirmed Computer AD  account $computerName is disabled" -ForegroundColor Yellow
        
        #Add condition: Check existing description to know why it is locked.
        $reason = $PcInfo.description
        Write-Host "`n"
        Write-Host "==============================" -foregroundcolor Yellow
        Write-Host "Disabled computer Description: " -foregroundcolor Green
        Write-Host "------------------------------" 
        Write-Host "$reason"
        Write-Host "`n"

        Write-Warning "To minimize security risk, Machines disabled longer than 6 Months should be rebuilt!"
        
        Write-Progress "Enabling AD account"
        #Confirm to proceed with enabling account -confirm:$true
        Get-ADComputer $computerName | Set-ADComputer -Enabled $true -Description " " -Confirm:$true

        #refresh computer info
        $PcInfo = Get-ADComputer $computerName
        $newStatus = $PcInfo.Enabled

        #Validate -if status changed - display changes
        if ($newStatus -eq $true) {
            Write-Progress "Moving AD account to respective OU"
            Get-ADComputer $computerName | Move-ADObject -TargetPath "OU=Standard SOE,OU=Computers,OU=Windows,DC=santos,DC=com"

            #refresh computer info
                $PcInfo = Get-ADComputer $computerName
                $newStatus = $PcInfo.Enabled
                $newPcOU = $PcInfo.DistinguishedName
            Write-Host "$computerName account status is now $newStatus!" -ForegroundColor Green
            Write-Host "$computerName has been moved to $newpcOU!" -ForegroundColor Green
            Write-Host "Connect device to Santos network and allow 30 minutes for replication.  " -ForegroundColor Yellow
        }
    } else {
        Write-Host "$computerName AD account is enabled - no further processing required - ending script." -ForegroundColor Red
    }
} Enable-AdComputerAccount