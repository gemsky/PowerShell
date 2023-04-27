#Title: Clear Credential manager
Write-Progress "Clearing Credential manager..."
    cmdkey /list | ForEach-Object{if($_ -like "*Target:*"){cmdkey /del:($_ -replace " ","" -replace "Target:","")}}

Write-Progress "Clearing Credential manager, Done!"
Add-Type -AssemblyName PresentationFramework
$msgBoxInput = [System.Windows.MessageBox]::Show(
                'Completed Credential manager clean up.',
                'Credential Manager',
                'Ok',
                'Warning'
                )
Exit