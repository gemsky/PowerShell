function Reset-CitrixProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]
        $userID
    )
    <#
    .SYNOPSIS
    Automates Citrix profile resets, streamlining the process and improving efficiency.

    .DESCRIPTION
    This PowerShell script automates the process of resetting Citrix profiles, simplifying the task and enhancing overall efficiency. It intelligently detects the user profile server location and active sessions associated with the specified user. The script provides an option to request approval from the customer before proceeding with the profile reset. Once approval is obtained, the script terminates the active session if necessary and proceeds to reset the Citrix profile for the specified user.

    By automating the Citrix profile reset process, this script eliminates manual steps and reduces downtime in Citrix environments. It ensures a consistent and reliable profile reset procedure, enhancing productivity and minimizing disruptions for end users.

    .PARAMETER UserName
    Specifies the username of the user whose Citrix profile needs to be reset.

    .PARAMETER RequestApproval
    Indicates whether to prompt for customer approval before proceeding with the profile reset. Default value is $true.

    .EXAMPLE
    Reset-CitrixProfile -UserName "johndoe"
    This example resets the Citrix profile for the user "johndoe". 

    .NOTES
    Author: G Lim
    Date: June 10, 2023
    Version: 1.0

    #>

    #Look for user Citrix Session
    Write-Host "==========================================================="
    Write-Host "Part 1: Find User Citrix Profile folder and active session!" -ForegroundColor Yellow
    Write-Host "==========================================================="

    #get user credentials
    Write-Progress "Confirming user details"
    #$userID = Read-Host "Enter userID to find user Citrix Session"

    #Create appended file variable
    $userFolderName = $userID + ".*"

    #List of Citrix user profiles as per KB
    #Write-Host "=================="
    Write-Host "Server options:" -ForegroundColor Yellow
    Write-Host "----------------"
    Write-Host "1. Tatooine: MillenniumFalcon"
    Write-Host "2. Hoth: JediMaster\citrix_profiles"
    Write-Host "3. Endor: DarthVader"
    Write-Host "4. Naboo: Chewbacca"
    Write-Host "5. Coruscant: PrincessLeia"
    Write-Host "=================="
    Write-Host " "

    #Create an array for profile repositories: To add: $profileFolders +=
    $sessions = @()

    #Loop until profile folder is found on the server
    do {
        $servers = Read-Host "Select the relevant Citrix server number"
        switch ($servers) {
            1 { $server = '\\MillenniumFalcon\Citrix-Profiles\' }
            2 { $server = '\\JediMaster\Citrix_Profiles\' }
            3 { $server = '\\DarthVader\citrix-profiles\' }
            4 { $server = '\\Chewbacca\citrix-profiles\' }
            5 { $server = '\\PrincessLeia\citrix-profiles\' }
        }
        
        Write-Progress "Checking profiles on $server"
        #get folder name with appended number on it .2 or .6
        $profileObjects = Get-ChildItem -Path $server | 
            Select-Object -Property Name |
                Where-Object {($_.Name -like $userFolderName -and $_.Name -notlike '*.old*' -and $_.Name -notlike '*-old*' -and $_.Name -notlike '*_old*')}
                
        Write-host " " 
        Write-Host "Results:" -ForegroundColor Yellow
        Write-host "========" 
        if ($profileObjects) {
            Write-Host "$userID profile folder exist on $server" -ForegroundColor Green
            Write-Progress "$userID profile folder exist on $server"
            $profileNames = $profileObjects.Name
            foreach($p in $profileNames){
                $fullPathProfile = $server + $p
                Write-Progress "Checking active sessions on $fullPathProfile" 
                $userSessions = Get-ChildItem -Path $fullPathProfile -Recurse | 
                    Select-Object -Property Name |
                        Where-Object {($_.Name -notlike "*$userID*" -and $_.Name -notlike 'RW.VHDX' -and $_.Name -notlike 'merge.VHDX')}
                
                #Refine server name @{Name=AWSCTXSOE006_ODFC.VHDX
                foreach ($userSession in $userSessions) {
                    $userSession = $userSession -replace ".*=" -replace "_.*"

                #Add to folder list array
                $sessions += $userSession
                }
            }
        } else {
            Write-Warning "$userID profile folder does NOT exist on $server"
        }     
    } until ($profileObjects)

    #Results:
    if ($sessions) {
        Write-host " "
        Write-host "Found  user active sessions on the following servers: " -ForegroundColor Red
        $sessions
        Write-host "=====================================================" -ForegroundColor Yellow
        Write-host " "    
        Write-Warning "Contact user to ask them to log-off Citrix sessions via 'Connection Center' "   
        Write-Warning "Ending script!"
        Return
    } else {
        Write-host "No active sessions Found! Good to proceed with Profile reset!" -ForegroundColor Green
        Write-host " "
    }

    Write-Progress "Confirming user details"
        Write-Host "====================================="
        Write-Host "Part 2: Reseting User Citrix Profile!" -ForegroundColor Yellow
        Write-Host "====================================="
        Write-Warning "Make sure you have notified and obtained user approval to proceed to reset their Citrix profile"

    #Confirmation GUI
    Add-Type -AssemblyName PresentationFramework
    $msgBoxInput = [System.Windows.MessageBox]::Show(
        'Make sure you have notified and obtained user approval to reset their Citrix profile! Proceed to Reset User Citrix Profile? ',
        'Reset Citrix Profile',
        'YesNo',
        'warning'
        )

    switch  ($msgBoxInput) {
        'Yes' {
            #Reset user profile: Look for user Citrix profile folder
            #Create Array for profile repositories: To add: $profileFolders +=
            $newProfileFolders = @()

            #Confirm to proceed with profile reset?
                Write-Progress "Requesting confirmation to reset profile!"

            #Find profile on $server
                Write-Progress "Checking profiles on $server"

            #get folder name with appended number on it .2 or .6
            $profileObjects = Get-ChildItem -Path $server | 
                Select-Object -Property Name |
                    Where-Object {($_.Name -like $userFolderName -and $_.Name -notlike '*.old*' -and $_.Name -notlike '*-old*' -and $_.Name -notlike '*_old*')}

            #Validate folder exist on selected server
                if (!($profileObjects)) {
                    Write-Warning "User Profile folder does not exist on this server: $server"
                    Write-host "Ending Script!" -ForegroundColor Yellow
                    exit
                } 

            #Foreach Profile found 
                $profileNames = $profileObjects.Name
                foreach($p in $profileNames){
                    Write-Progress "$userID profile folder exist in $server"
                    #combine to make full path
                        $fullPathProfile = $server + $p
                        Write-Host "Full Path to sys profile folder is: $fullPathProfile"

                    #Create New folder Name
                        Write-Progress "Create new folder Name..."
                        #get username and date to append
                        $date = get-date -Format ddMMyyHHmm
                        $dotOldNameDate = ".old." + $env:USERNAME + "."+$date

                        #Set new folder name
                        $newFolderName = $p + $dotOldNameDate
                    
                    #Rename-item -path $filefullPath -newName $newFolderName
                        try{
                            Write-Progress "Renaming CTX Sys profile folder..."
                            Rename-Item -Path $fullPathProfile -NewName $newFolderName -ErrorAction SilentlyContinue
                            
                        } catch {
                            Write-Host $_.Exception
                            throw
                            Write-Host "Failed! Check Citrix cloud for user sessions" -ForegroundColor Red
                        }
                
                    #Validate
                        $newUncPath = $server + $newFolderName
                        if (test-path $newUncPath) {
                            Write-Progress "$newUncPath Succesfull!"
                            $newProfileFolders += $newUncPath
                        } else {
                            $newObject = $fullPathProfile + " Failed!"
                            $newProfileFolders += $newObject
                        }
                        Write-host "===================" -ForegroundColor Yellow
                        Write-host "Renamed Results: " -ForegroundColor Green
                        $newProfileFolders

                        #move Folder to Reset_profiles
                        $resetFolderPath = "$server" + "RESET_Profiles"
                        foreach ($oldProfile in $newProfileFolders) {
                            Write-Progress "Moving $oldProfile to $resetFolderPath"
                            Move-Item -path "$oldProfile" -Destination $resetFolderPath -Force
                            Write-Host "$oldProfile moved to $resetFolderPath successfully"
                        } 
                        Write-host "Successfully renamed $userID Citrix profile folder." -ForegroundColor Green
                        Write-host "Please log back in to your citrix app and confirm if issue is now resolved." -ForegroundColor Green
                        Write-host "Let me know how you go." -ForegroundColor Green
                }
        } 
        'No'{ 
            Return 
        }
    }
}
