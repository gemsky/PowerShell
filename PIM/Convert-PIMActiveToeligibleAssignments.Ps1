function Convert-PimEligibleAssignments {
<#
.SYNOPSIS
Retrieves the eligible assignments for Azure Privileged Identity Management (PIM) roles based on a predefined group list.

.DESCRIPTION
The Convert-PimEligibleAssignments function retrieves the eligible assignments for Azure Privileged Identity Management (PIM) roles. It uses a predefined group list to identify the groups for which the eligible assignments need to be retrieved. The function processes each group in the list, retrieves the Azure AD group corresponding to the group name, and then retrieves the eligible assignments for that group using the Get-AzureADMSPrivilegedRoleAssignment cmdlet. The eligible assignments are stored in an array of objects, and the results are exported to a CSV file and displayed on the console.

.EXAMPLE
Convert-PimEligibleAssignments
This example retrieves the eligible assignments for Azure PIM roles based on the predefined group list. The results are logged in a CSV file and displayed on the console.

.NOTES
Author: G Lim
Date: June 10, 2023
Version: 1.0
#>

#Group List
$groups = @(
    "M365 GDAP Exchange Administrator",
    "M365 GDAP Groups Administrator",
    "M365 GDAP Helpdesk Administrator",
    "M365 GDAP SharePoint Administrator",
    "M365 GDAP Teams Administrator",
    "M365 GDAP User Administrator"
    "M365 GDAP Application Administrator",
    "M365 GDAP Authentication Policy Administrator",
    "M365 GDAP Billing Administrator",
    "M365 GDAP Cloud App Security Administrator",
    "M365 GDAP Cloud Device Administrator",
    "M365 GDAP Compliance Administrator",
    "M365 GDAP Domain Name Administrator",
    "M365 GDAP Intune Administrator",
    "M365 GDAP License Administrator",
    "M365 GDAP Power BI Administrator",
    "M365 GDAP Power Platform Administrator",
    "M365 GDAP Security Administrator",
    "M365 GDAP Service Support Administrator"
)
$path = "C:\temp\GdapEligible.csv"
#check if file exist - delete
if (Test-Path $path) {
    Remove-Item $path
}
$results = @()
$groups | ForEach-Object {

# Get the Azure AD group
$groupID = (Get-AzureADGroup -Filter "DisplayName eq '$_'").ObjectId
#$groupID = (Get-AzureADGroup -Filter "DisplayName eq 'M365 GDAP Exchange Administrator'").ObjectId

# Store all the active assignments
Write-Progress -Activity "Processing $_" -Status "Processing Active Assignments"
$pimGroups = Get-AzureADMSPrivilegedRoleAssignment -providerID 'aadGroups' -resourceID $groupId | where {$_.AssignmentState -eq "eligible"}

    # Change all the role's active assignments to eligible
    foreach ($group in $pimGroups) {
        $groupDisplayName =  (Get-AzADGroup -ObjectId $group.ResourceId).DisplayName
        $userDisplayName = (Get-AzADUser -ObjectId $group.SubjectId).DisplayName
        Write-Progress -Activity "Processing $groupDisplayName" -Status "Processing $userDisplayName"
        #create psobject
        $results += New-Object -TypeName PSObject -Property @{
            GroupName = $groupDisplayName
            User = $userDisplayName
            AssignmentState = $group.AssignmentState
            ID = $group.Id
        }
    }
} #End of foreach
$results | Export-Csv -Path $path -NoTypeInformation
$results | Sort User |Format-Table -AutoSize
Write-Host -f green "Results has been logged in $path"
}
Get-PimEligibleAssignments
