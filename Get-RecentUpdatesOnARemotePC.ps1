function Get-RecentUpdateList {
    Param(
        [Parameter(Mandatory=$false,
        ValueFromPipeline=$true,
        position=0)]
        [string[]]
        $ComputerName
    )
<#
.SYNOPSIS
Get Computer recent updates
.DESCRIPTION
This script will connect to the computer and get the recent updates list on the computer. 
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
.\Get-RecentUpdatesOnARemotePC.ps1
.NOTES
Old command - only gets Win updates: Get-CimInstance -ComputerName $computerName -ClassName Win32_QuickFixEngineering | 
            Sort-Object InstalledOn | 
                FT HotFixID, InstalledOn, Description, InstalledBy
#>
Write-Progress " Getting recent updates.."
Function Get-MicrosoftUpdates{
Param(
$NumberOfUpdates,
[switch]$all
)
$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()
if($all)
{
$HistoryCount = $Searcher.GetTotalHistoryCount()
$Searcher.QueryHistory(0,$HistoryCount)
}
Else { $Searcher.QueryHistory(0,$NumberOfUpdates) }
} #end Get-MicrosoftUpdates

if ($null -ne $ComputerName ) {
    #check if machine is online
    Write-Progress " Getting recent updates" -Status "Checking if $computerName is online"
    if (Test-Connection -ComputerName $computerName -Count 1 -quiet) {
        Write-Host "$computerName is Online!" -ForegroundColor Green
        
        Write-Progress " Getting recent updates" -Status "Connecting .."
        Invoke-Command -ComputerName $computerName -ScriptBlock {
            #Call function and list updates
            Write-Progress " Getting recent updates" -Status "Colelcting data.."
            Get-MicrosoftUpdates -All | Format-Table Date, Title
        }

    } else {
        Write-Host "$computerName is currently Offline Or unreachable - ending script!" -ForegroundColor Red
    }
} else {
    #Call function and list updates
    Write-Progress " Getting recent updates" -Status "Colelcting data.."
    Get-MicrosoftUpdates -All | Format-Table Date, Title
}
} #end function

