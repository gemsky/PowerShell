Param (
[string]$Computer = (Read-Host Remote computer name),
[int]$Days = 5
)

$Result = @()
Write-Progress "Gathering Event Logs, this can take awhile..."
$ELogs = Get-EventLog System -Source Microsoft-Windows-WinLogon -After (Get-Date).AddDays(-$Days) -ComputerName $Computer
If ($ELogs){ 
    Write-Progress "Processing..."
    ForEach ($Log in $ELogs){ 
        Write-Progress "Processing... $Log"
        If ($Log.InstanceId -eq 7001){ 
            $ET = "Logon"
        } ElseIf ($Log.InstanceId -eq 7002){
            $ET = "Logoff"
        } Else {
            Continue
        }

        $Result += New-Object PSObject -Property @{
        Time = $Log.TimeWritten
        'Event Type' = $ET
        User = (New-Object System.Security.Principal.SecurityIdentifier $Log.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount])
        }
    }

    $Result | Select Time,"Event Type",User | Sort Time -Descending
    #Export-CSV c:\path\report.csv -NoTypeInformation 
    Write-Host "Done."
} Else { 
    Write-Host "Problem with $Computer."
    Write-Host "If you see a 'Network Path not found' error, try starting the Remote Registry service on that computer."
}