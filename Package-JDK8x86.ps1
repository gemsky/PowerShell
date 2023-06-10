#SCCM Packaging Script
<#
.SYNOPSIS
SCCM Packaging Script for Oracle Java Development Kit 8 x86 Update 202_8.

.DESCRIPTION
This script is used for packaging Oracle Java Development Kit 8 x86 Update 202_8 for deployment using Microsoft System Center Configuration Manager (SCCM).

.PARAMETER SourcePath
Specifies the path to the source files of Oracle Java Development Kit 8 x86 Update 202_8.

.PARAMETER OutputPath
Specifies the path where the SCCM package will be created.

.EXAMPLE
.\SCCMPackagingScript.ps1 -SourcePath "C:\Java8\x86\Update202_8" -OutputPath "C:\SCCMPackages\Java8_Update202_8"
Creates an SCCM package for Oracle Java Development Kit 8 x86 Update 202_8 using the files located at C:\Java8\x86\Update202_8 and saves the package to C:\SCCMPackages\Java8_Update202_8.

.NOTES
- Ensure you have the necessary permissions and valid credentials to access the source files and create SCCM packages.
- The script assumes that you have the required SCCM tools and environment configured.
- Modify the SCCM package settings, such as installation command, detection method, and distribution points, as per your organization's requirements.
- Test the SCCM package thoroughly before deploying it in a production environment.
#>

#variables:
    #New App Variables
    $Name = "Oracle_JavaDevelopmentKit8x86Update202_8.0.2020.8_1.0_M"
    $description = "Last free Version of Java Development Kit - End of Public Update/ end of Premier Support: March 2022/ Extended Support: December 2030/Sustaining Support: Indefinite"
    $publisher = "Oracle"
    $softwareVersion = "8.0.2020.8"
    # $icon = optional

    #Deployment Type Variables
    $ContentLocation = "\\SCCM\SCCM-PKG\Oracle\Oracle_JavaDevelopmentKit8x86Update202_8.0.2020.8_1.0_M\jdk1.8.0_202.msi"
    $InstallCommand = "Install-JDK8x86.ps1"
    $UninstallCommand = "MsiExec.exe /X{32A3A4F4-B792-11D6-A78A-00B0D0180202}"

#Start automation
#New App
    $cmAppsArgs = @{
        Name = $Name
        description = $description
        publisher = $publisher
        softwareVersion = $softwareVersion
        verbose = $true
    }
    #Create New app
    New-CMApplication @cmAppsArgs



#New Deployment Type
    $CMMsiDeploymentTypeArgs = @{
        ApplicationName = $Name 
        ContentLocation = $ContentLocation 
        InstallationBehaviorType = "InstallForSystem" 
        InstallCommand = $InstallCommand 
        UninstallCommand = $UninstallCommand 
        DeploymentTypeName = $Name 
        Force = $true
        Verbose = $true
    }
    #Add Deployment type
    Add-CMMsiDeploymentType @CMMsiDeploymentTypeArgs


    #to deploy to all dps:
    $dps = (Get-CMDistributionPointInfo).Name

    #Add app to distribution points
    foreach ($dp in $dps) {
        Start-CMContentDistribution -ApplicationName $Name -DistributionPointName $dp
    }

#Create new Collection
#New-CMCollection -CollectionType  Device -Name $Name -LimitingCollectionName "All Windows 7, 8.X, 10, 11 Computers" -Comment $description
    $CMCollectionArgs = @{
        CollectionType = "Device "
        Name = $Name 
        LimitingCollectionName = "All Windows 7, 8.X, 10, 11 Computers" 
        Comment = $description
    }
    New-CMCollection @CMCollectionArgs

#Deploy to  Device Collection
#New-CMApplicationDeployment -CollectionName $Name -Name $Name -DeployAction Install -DeployPurpose Required -UserNotification DisplaySoftwareCenterOnly -AvailableDateTime (Get-Date) -TimeBaseOn LocalTime
    $CMApplicationDeploymentArgs = @{
        CollectionName = $Name 
        Name = $Name 
        DeployAction = "Install" 
        DeployPurpose = "Required" 
        UserNotification = "DisplaySoftwareCenterOnly"  
        AvailableDateTime = (Get-Date)
        TimeBaseOn = "LocalTime"
    }

    #Deploy App to Collection
    New-CMApplicationDeployment @CMApplicationDeploymentArgs 
