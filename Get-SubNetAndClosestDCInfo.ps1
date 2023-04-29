function GetSubNetAndClosestDCInfo {
param (
[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]$computerName
)
    Write-Progress "$computerName>Get Online status.."
    if (Test-Connection -ComputerName $computerName -Count 1 -quiet -ErrorAction SilentlyContinue) {
        Write-Progress "$computerName is Online! Connecting.."
    } else {
        Write-Host "$computerName>Offline!" -ForegroundColor Red
        Return
    }        
    Write-Progress "Get current active Domain controller list..."
    $DCs = Get-ADDomainController -Filter * 
    Write-Progress "Connecting to $computerName.."
    Invoke-Command -ComputerName $computerName -ScriptBlock {
        $hostName = $env:computerName
        Write-Progress "$hostName> Connected!"
        Write-Host "$hostName has been identified on an unknown subnet and failing to patch critical update." -ForegroundColor Green
        Write-Host "====================" -ForegroundColor Yellow
        Write-Host "Device Network Info:"
        Write-Host "--------------------" -ForegroundColor Yellow
        Write-Progress "$hostName> Getting network info.."
        $pcSubnetInfoArray = @()
        $ipInfo = Get-WmiObject Win32_NetworkAdapterConfiguration | where IPEnabled -eq $true
        $IPAddress = $ipInfo.IPAddress[0]
        $IPSubnet = $ipInfo.IPSubnet[0]
        $DefaultIPGateway = $ipInfo.DefaultIPGateway[0]
        $pcSubnetInfoArray += [PSCustomObject]@{
            IPAddress = $IPAddress;
            Subnet = $IPSubnet;
            DefaultGateway = $DefaultIPGateway
        }
        $pcSubnetInfoArray | FL

        Write-Progress "Get DC connection info.."
        $dcResponseTimeArray = @()
        ForEach($DC in $using:DCs){
            $dcName = $DC.Name
            $site = $DC.Site
            Write-Progress "Test connection to $dcName>$site"
            $connection = Test-Connection $dcName -count 1 -ErrorAction SilentlyContinue
            $ResponseTime = $connection.ResponseTime
            if ($ResponseTime -eq $null ) {
                Write-Progress "Skipping Virtual DCs>$dcName>$site"
            } else {            
                Write-Progress "Adding results to array $dcName>$site"
                $dcResponseTimeArray += [PSCustomObject]@{
                    Name = $hostName;
                    DC = $dcName;
                    Site = $site;
                    ResponseTime =$ResponseTime
                }
            } 
        }
        Write-Progress "Object array created: sorting by lowest response time.."
        Write-Host "---------------------------------------------------" -ForegroundColor Yellow
        Write-Host "Top 5 DCs sorted by lowest connecting ResponseTime:"
        Write-Host "---------------------------------------------------" -ForegroundColor Yellow
        $dcResponseTimeArray | sort ResponseTime | select -First 5 | FT
        Write-Host "===================================================" -ForegroundColor Yellow
        Write-Host "@Network Team: Please assist to Assist to confirm: New SubNet site name and Best DC for the site authentication, then Escalate to Windows Team" -ForegroundColor Green
        Write-Host "@Windows Team: Please assist to add new subnet with confrimed site information by Network team. Once completed, please escalate to Messaging" -ForegroundColor Green
        Write-Host "@Messaging Team: Please assist to confirm new subnet is also reflected correctly in SCCM boundary respectively" -ForegroundColor Green
        
    }
} GetSubNetAndClosestDCInfo