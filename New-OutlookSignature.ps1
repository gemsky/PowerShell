<#
.SYNOPSIS
Outlook Signature for desktop and mobile devices
.DESCRIPTION
This PowerShell script leverages Active Directory properties to populate an HTML signature, which is then saved in the designated $signatureFolder with the name $filename.htm. 
The script can be executed as a scheduled task at logon or ideally as a Group Policy Logon script, configuration management tool, or any other method for running a script at logon.
The script incorporates if statements to ensure that certain sections of the signature are included only if the user has specific properties available. 
For example, if a user doesn't have a mobile number, that section of the signature will be excluded, resulting in a more professional appearance. 
If the user is assigned a mobile number, it will be automatically added to their signature during the next logon.
Additionally, the script provides the option for users to set up an Outlook mobile signature. 
The script generates a new signature specifically designed for mobile devices and sends it to their mailbox via email. 
Users are then required to manually copy the signature from the email and paste it into the Outlook mobile app.
Upon completion, the script prompts the user to restart their computer for the changes to take effect, ensuring that the updated signature is applied accordingly.

By employing this script, organizations can streamline the process of generating consistent and dynamic email signatures based on Active Directory properties, enhancing the professionalism and customization of their email communication.

.INPUTS
Several properties for the user are taken directly from Active Directory, and user input is requested for Mobile signature confirmation and mobile phone type.
.OUTPUTS
$signatureFolder\$filename.htm - HTML signature for rich text emails

.NOTES
Version:        1.0
Author:         G Lim
Modified:       11/07/2023
#>

Write-Progress -Activity "Updating  Signature" -Status "Getting user data..." -PercentComplete 10
# Getting Active Directory information for current user
try {
    $user = (([adsisearcher]"(&(objectCategory=User)(samaccountname=$env:username))").FindOne().Properties)
}
catch {
    Write-Warning "Unable to connect to Domain and Active Directory! make sure you are connected to company Network!"
    exit
}

#Desktop Signature
    # Create the signatures folder and sets the name of the signature file
    Write-Progress -Activity "Updating  Signature" -Status "Validating signature folder..." -PercentComplete 20
    $signatureFolder = $Env:appdata + '\\Microsoft\\signatures'
    if(!(Test-Path -Path $signatureFolder )){
        New-Item -ItemType directory -Path $signatureFolder
    }

    #Convert image to base64
    Write-Progress -Activity "Updating  Signature" -Status "Getting banner images..." -PercentComplete 40
            $imageUrl = "https://raw.githubusercontent.com/gemsky/PowerShell/main/CloudSmartSolutionBanner.png" #Change this to your own url
            $imageBytes = (Invoke-WebRequest -Uri $imageUrl -UseBasicParsing).Content
            # Convert the image to a base64-encoded string
            $logo1 = [System.Convert]::ToBase64String($imageBytes)
            $logo1Height = "height='140'"

    # Get the users properties (These should always be in Active Directory and Unique)
    Write-Progress -Activity "Updating  Signature" -Status "Creating user Signature..." -PercentComplete 60
    if($user.name.count -gt 0){$displayName = $user.name[0]}
    if($user.title.count -gt 0){$jobTitle = $user.title[0]}
    if($user.mobile.count -gt 0){$mobileNumber = $user.mobile[0]}
    if($user.mail.count -gt 0){$email = $user.mail[0]}

    #Create File Name
    $filename = "Signature ($($email))"
    $file  = "$signatureFolder\\$filename"

    # BusinessAddress
    $AdressLine1 = "Ground Floor, Suite 10 , Cloud Business Complex"
    $AdressLine2 = "10 Cloud Street, Smart, West Cloud 3333"
    $telephone = "+61 8 6333 3333"
    $website = "cloudSmart.com.au"

#-DO NOT CHANGE INDENTATION    
Write-Progress -Activity "Updating  Signature" -Status "Building HTML file" -PercentComplete 80
# Building Style Sheet
$style = 
@"
<style>
<!--
 /* Font Definitions */
 @font-face
	{font-family:"Cambria Math";
	panose-1:2 4 5 3 5 4 6 3 2 4;}
@font-face
	{font-family:Calibri;
	panose-1:2 15 5 2 2 2 4 3 2 4;}
 /* Style Definitions */
 p.MsoNormal, li.MsoNormal, div.MsoNormal
	{margin:0cm;
	font-size:11.0pt;
	font-family:"Calibri",sans-serif;}
.MsoChpDefault
	{font-family:"Calibri",sans-serif;}
.MsoPapDefault
	{margin-bottom:8.0pt;
	line-height:107%;}
@page WordSection1
	{size:595.3pt 841.9pt;
	margin:72.0pt 72.0pt 72.0pt 72.0pt;}
div.WordSection1
	{page:WordSection1;}
-->
</style>
"@

# Building HTML
$signature = 
@"  
<body>
    <table cellspacing="0" cellpadding="0" style="width: 100%;">
        <tr>
            <td style='font-family: Arial; font-size: 11px;'>
                $(if($displayName){"<span style='color: purple; font-size: 14px; font-weight: bold; line-height: 1;'>"+$displayName+"</span><br />"})
                $(if($jobTitle){"<span style='color: purple; font-weight: bold; font-size: 14px; line-height: 1;'>"+$jobTitle+"</span><br />"})
                <p style='color: purple;'>
                    $(if($mobileNumber){"<span style='color: purple; font-weight: bold; line-height: 1;'>MOBILE </span> <a href='tel:$mobileNumber' style='text-decoration: none; color: #331664;'>$($mobileNumber)</a><br />"})
                    $(if($telephone){"<span style='color: purple; font-weight: bold; line-height: 1;'>OFFICE </span> <a href='tel:$telephone'  style='text-decoration: none; color: #331664;'>$($telephone)</a><br />"})
                    $(if($AdressLine1){"<span style='line-height: 1;'>$($AdressLine1 -replace '\|', "<span style='color: purple;'>|</span>")</Span><br />"})
                    $(if($AdressLine2){"<span style='line-height: 1;'>$($AdressLine2 -replace '\|', "<span style='color: purple;'>|</span>")</Span><br /><br />"})
                    $(if($website){"<span style='color: purple; font-weight: bold; line-height: 2;'>WEBSITE </span> <a href='https://$website' style='text-decoration: none; font-size: 12px; font-weight: bold; color: #331664;'>$($website)</a><br /><br />"})
                </p>
            </td>
        </tr>
        <tr>
            <td>
                <img src="data:image/png;base64,$logo1" alt="EmailLogosLockOffRGB" width="510" $logo1Height style='margin-bottom: 10px;'><br />
            </td>
        </tr>
        <tr>
            <td>
                <div class=WordSection1>
                    <p class=MsoNormal><span style='font-size:8.0pt;font-family:"Arial",sans-serif;
                    'color: grey'>If you are not an authorised recipient of this email, please
                    contact Cloud Smart Services immediately</span></p>

                    <p class=MsoNormal><span style='font-size:8.0pt;font-family:"Arial",sans-serif;
                    'color: grey'>by return <u1:p></u1:p>email or by telephone. In this case, you
                    should not read, print, re-transmit, store or act in reliance</span></p>

                    <p class=MsoNormal><span style='font-size:8.0pt;font-family:"Arial",sans-serif;
                    'color: grey'>on this email or <u1:p></u1:p>any attachments, and should
                    destroy all copies of them. This email and its attachments are</span></p>

                    <p class=MsoNormal><span style='font-size:8.0pt;font-family:"Arial",sans-serif;
                    'color: grey'>confidential and may <u1:p></u1:p>contain legally privileged
                    information and / or copyright material of Cloud Smart Solutions</span></p>

                    <p class=MsoNormal><span style='font-size:8.0pt;font-family:"Arial",sans-serif;
                    'color: grey'>Services or third parties. You <u1:p></u1:p>should only
                    re-transmit, distribute or commercialise the material if you are</span></p>

                    <p class=MsoNormal><span style='font-size:8.0pt;font-family:"Arial",sans-serif;
                    'color: grey'>authorised to do so. This notice should <u1:p></u1:p>not be
                    removed.<u1:p></u1:p></span></p>
                </td>
            </div>
        </tr>
    </table>
</body>

"@
#-DO NOT CHANGE INDENTATION    

    # Save the HTML to the signature file
    $style + $signature | out-file "$file.htm" -encoding ascii

    # Setting the regkeys for Outlook 2016
    if (test-path "HKCU:\\Software\\Microsoft\\Office\\16.0\\Common\\General"){
        Write-Progress -Activity "Updating  Signature" -Status "Updating Registry..." -PercentComplete 85 
        get-item -path HKCU:\\Software\\Microsoft\\Office\\16.0\\Common\\General | new-Itemproperty -name Signatures -value signatures -propertytype string -force
        get-item -path HKCU:\\Software\\Microsoft\\Office\\16.0\\Common\\MailSettings | new-Itemproperty -name NewSignature -value $filename -propertytype string -force
        get-item -path HKCU:\\Software\\Microsoft\\Office\\16.0\\Common\\MailSettings | new-Itemproperty -name ReplySignature -value $filename -propertytype string -force
        Remove-ItemProperty -Path HKCU:\\Software\\Microsoft\\Office\\16.0\\Outlook\\Setup -Name "First-Run" -ErrorAction silentlycontinue
    }

#Mobile Signature
    # Save the HTML to the signature file
    $style + $signature | out-file "$file.html" -encoding ascii

    # Send the HTML in an email as attchement to $email via outlook
    $outlook = New-Object -ComObject Outlook.Application
    $mail = $outlook.CreateItem(0)
    $mail.Attachments.Add("$file.html")
    $mail.To = $email
    $mail.Subject = "Outlook Mobile Signature"
    $mail.Send()
    
    #Create a windows popup with GReen Check icon with 1 button 'ok' to notify the user that the email has been sent and proceed from their mobile device.
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Your mobile signature has been sent to $email. Please proceed on your mobile device to copy attachement content to Outlook Mobile app signature.", 0, " Mobile Signature.", 64)
    cls

#Create a windows popup  with 1 button 'ok' to notify the user that the email has been sent and proceed from their mobile device.
    cls
    Write-Progress -Activity "Updating  Signature" -Status "Pending user confirmation!" -PercentComplete 95
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Your  signature has been Updated. Please proceed to restart your device for change to take effect.", 0, "Microsoft Outlook  Signature Update.", 64)
