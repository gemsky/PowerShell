#Title: Copy Installation files manually to destination PC
#Get PC Name
    $pcName = Read-Host "Enter SanNumber name to add to collection"

#Get Installation files repository
    $source = Read-host "Enter Application installation Folder Full UNC path"
        #Validate source files
        if (!(Test-Path $source)) {
            Write-Warning "Source folder path does NOT exit - confirm source folder path"
            Exit
        }
    $sourceSizeb = (Get-ChildItem $source -Recurse | Where-Object { -not $_.PSIsContainer } | Measure-Object -property length -sum).sum
    $sourceSize = [math]::Round(($sourceSizeb / 1MB),2)

    $folderName = (Split-path $source -Leaf)
    $destination = "\\$pcName\C$\Scratch\$folderName"
        #Validate Destination files
        if (!(Test-Path $source)) {
            Write-Warning "Source folder path does NOT exit - confirm source folder path"
            Exit
        }

#confirm PC Online
    if (!(Test-Connection -ComputerName $pcName -count 1 -Quiet)) {
        Write-Host "Computer Offline! Ending Script!" -ForegroundColor Red
        Exit
    } Write-Host "Computer Online! " -ForegroundColor Green

#Check Folder exist else create
    $path = "\\$pcName\C$\Scratch\"
    if (!($destination)) {
        New-Item -Path $path -Name $folderName -ItemType "directory"
    } else {
        #Validate Destination files
        Write-Warning "Installation folder detected on destination PC!"
        Write-Progress "Validating files..."
        $destSizeb = (Get-ChildItem $destination -Recurse | Where-Object { -not $_.PSIsContainer } | Measure-Object -property length -sum).sum 
        $destSize = [math]::Round(($destSizeb / 1MB),2)
        Write-Host "Original Folder size: $sourceSize MB"
        Write-Host "Destination Folder size: $destSize MB"
        if ($sourceSize -eq $destSize ) {
            Write-warning "Installation files already exist - ending Script!"
            Exit
        }    
    }

#Initiate Robocopy
    Robocopy $source $destination /E /Z

#Validate
$destSizeb = (Get-ChildItem $destination -Recurse | Where-Object { -not $_.PSIsContainer } | Measure-Object -property length -sum).sum 
$destSize = [math]::Round(($destSizeb / 1MB),2)

Write-Host "Original Folder size: $sourceSize MB"
Write-Host "Destination Folder size: $destSize MB"
if ($sourceSize -eq $destSize ) {
    Write-Host "Successfully copied $folderName to $pcName" -ForegroundColor Green
} else {
    Write-Host "Validation failed!" -ForegroundColor Red
    Write-Progress "waiting"
    Start-Sleep -Seconds 60
    Robocopy $source $destination /MIR /XO /R:5 /W:10
    $destSize = (Get-ChildItem $destination -Recurse | Where-Object { -not $_.PSIsContainer } | Measure-Object -property length -sum).sum 
    Write-Host "Original Folder size: $sourceSize MB"
    Write-Host "Destination Folder size: $destSize MB"
}