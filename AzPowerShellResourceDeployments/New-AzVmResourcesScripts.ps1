#Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#Connect to Az
Connect-AzAccount -TenantId "fdc1b377-67cb-48d8-bdaa-a9312f837c1a" -Verbose
Set-AzContext -SubscriptionId "8a960960-3db1-46b6-a6e5-1307dc129244"

#Variables
$location = "AustraliaEast"
$name = "Az104"
$domainNameLabel = "az104dnl" # randome based on "^[a-z][a-z0-9-]{0,61}[a-z0-9]$" regex requirement
#VM Credentials
$userName = $name + "4dm1n"
$password = $name + "4dm1n2023"
$vmCred = New-Object System.Management.Automation.PSCredential ($userName, (ConvertTo-SecureString $password -AsPlainText -Force))

#Create Resource Group
$rgName = $name + "-RG"
$rgParams = @{
    Name = $rgName
    Location = $location
}
New-AzResourceGroup @rgParams

#Create Virtual Network
$subnetConfigDefault = New-AzVirtualNetworkSubnetConfig -Name "Default" -AddressPrefix "10.0.1.0/24"
$subnetConfigSS = New-AzVirtualNetworkSubnetConfig -Name "ssSubnet" -AddressPrefix "10.0.2.0/24"
$subnetConfigFW = New-AzVirtualNetworkSubnetConfig -Name "AzureFirewallSubnet" -AddressPrefix "10.0.3.0/24"

$VNetName = $name + "-VNet"
$vnetParams = @{
    ResourceGroupName = $rgName
    Name = $VNetName
    Location = $location
    AddressPrefix = "10.0.0.0/16"
    Subnet = $subnetConfigDefault, $subnetConfigFW, $subnetConfigSS
}
$vNet = New-AzVirtualNetwork @vnetParams
#$vNet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $rgName

#Create network Security Group
    #Create NSG Rule
    $nsgRuleParams = @{
    Name = 'VNetNsgRuleRDP'  
    Protocol = 'Tcp' 
    Direction = 'Inbound' 
    Priority = '1000' 
    SourceAddressPrefix = '*' 
    SourcePortRange = '*' 
    DestinationAddressPrefix = '*' 
    DestinationPortRange = '3389' 
    Access = 'allow'
    }
    $nsgRuleRDP = New-AzNetworkSecurityRuleConfig @nsgRuleParams

    $nsgName = $name + "-NSG"
    $nsgParams = @{
        ResourceGroupName = $rgName
        Name = $nsgName
        Location = $location
        SecurityRules = $nsgRuleRDP
    }   
    $nsg = New-AzNetworkSecurityGroup @nsgParams

#Create VM with Azure Spot with AzVM cmdlets to disable Monitoring and Diagnostics
$VMName = "AZ104VmSpot-Srv03"
$VMSize = "Standard_DS1_v2"
    #Create Nic
    $pIpName = $name + "-PublicIP"
    $pIP = New-AzPublicIpAddress -Name $pIpName -ResourceGroupName $rgName -Location $location -AllocationMethod "Static" -Sku "Standard"
    $nicName = $VMName + "-NIC"
    $nicParams = @{
        Name = $nicName 
        ResourceGroupName = $rgName 
        Location = $location 
        SubnetId = $vnet.Subnets[0].Id 
        PublicIpAddressId = $pip.Id 
        NetworkSecurityGroupId = $nsg.Id
    }
    $nic = New-AzNetworkInterface @nicParams
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
    $VirtualMachine | Set-AzVMBootDiagnostic -Disable
    New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -Verbose

#Add data disk
    #Variables
    $diskName = $VMName + "-DataDisk"
    $vm = Get-AzVM -Name $VMName -ResourceGroupName $rgName
    $diskConfig = New-AzDiskConfig -SkuName Standard_LRS -Location $location -CreateOption Empty -DiskSizeGB 128
    $dataDisk = New-AzDisk -DiskName $diskName -Disk $diskConfig -ResourceGroupName $rgName
    $vm = Add-AzVMDataDisk -VM $vm -Name $diskName -CreateOption Attach -ManagedDiskId $dataDisk.Id -Lun 1
    Update-AzVM -VM $vm -ResourceGroupName $rgName


<# End of Create VM process! #>

function New-AzVMWinSrv2016 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory= $false, HelpMessage = "Provide resource version id: 0 - 10.")]
        [String]
        $resourceSuffix,
        [Parameter(Mandatory= $false, HelpMessage = "Provide new device suffix id: 0 - 10.")]
        [String]
        $deviceSuffix
    )

#Create VM with Azure Spot with AzVM cmdlets to disable Monitoring and Diagnostics
$nameVer = $name + $resourceSuffix

#VM Credentials
$userName = $nameVer + "4dm1n"
$password = $nameVer + "4dm1n2023"
$vmCred = New-Object System.Management.Automation.PSCredential ($userName, (ConvertTo-SecureString $password -AsPlainText -Force))

#Create Server name
$VMName = $nameVer + "WSrv" + $deviceSuffix +"-VM" 
    #check if vm name exists else $devicesuffix + 1
    if (Get-AzVM -Name $VMName -ResourceGroupName $rgName -ErrorAction SilentlyContinue) {
        Write-Warning "VM name $VMName already exists - incrementing device suffix"    
        $currentSuffix = $VMName.Substring($VMName.Length - 2)
        $deviceSuffix = [int]$currentSuffix + 1
        $VMName = $nameVer + "-WSrvVM" + $deviceSuffix.ToString("D2")
    }

#configure VM NIC
    #create a public IP address
    $publicIpName = $VMName.Replace("-","") + "-PIP"
    $pipParams = @{
        ResourceGroupName = $rgName
        Name = $publicIpName
        Location = $location
        AllocationMethod = "Dynamic"
    }
    $PIp = New-AzPublicIpAddress @pipParams
    #Create ipConfig
    $vnet = Get-AzVirtualNetwork -Name ($nameVer + "-VNet") -ResourceGroupName $rgName
    $ipConfigParams = @{
        Name = $nameVer + "IPConfig"
        SubnetId = $vnet.Subnets[0].id
        PublicIpAddressId = $PIp.id
        PrivateIpAddressVersion = "IPv4"
    }
    $IPconfig = New-AzNetworkInterfaceIpConfig @ipConfigParams
    #Create NIC
    $nicName = $VMName.Replace("-","") + "-NIC"
    $nicParams = @{
        Name = $nicName
        ResourceGroupName = $rgName
        Location = $location
        NetworkSecurityGroupId = $nsg.Id
        IpConfiguration = $IPconfig

    }
    $nic = New-AzNetworkInterface @nicParams
    #$nic = get-aznetworkinterface -Name $nicName -ResourceGroupName $rgName

$VMSize = "Standard_DS1_v2"
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
$VirtualMachine | Set-AzVMBootDiagnostic -Disable
New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -Verbose
Write-Host "$vmName Created Successfully!> Device credentials: $userName, $password" -f Green
} 
New-AzVMWinSrv2016 -resourceSuffix "01" -deviceSuffix "01"

function New-AzVMWin10 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory= $false, HelpMessage = "Provide resource version id: 0 - 10.")]
        [String]
        $resourceSuffix,
        [Parameter(Mandatory= $false, HelpMessage = "Provide new device suffix id: 0 - 10.")]
        [String]
        $deviceSuffix
    )

#Create VM with Azure Spot with AzVM cmdlets to disable Monitoring and Diagnostics
#Naming convention
$nameVer = $name + $resourceSuffix

#VM Credentials
$userName = $nameVer + "4dm1n"
$password = $nameVer + "4dm1n2023"
$vmCred = New-Object System.Management.Automation.PSCredential ($userName, (ConvertTo-SecureString $password -AsPlainText -Force))

#Create Device name
$VMName = $nameVer + "Wx" + $deviceSuffix + "-VM"
    #check if vm name exists else $devicesuffix + 1
    if (Get-AzVM -Name $VMName -ResourceGroupName $rgName -ErrorAction SilentlyContinue) {
        Write-Warning "VM name $VMName already exists - incrementing device suffix"    
        $currentSuffix = $VMName.Substring($VMName.Length - 2)
        $deviceSuffix = [int]$currentSuffix + 1
        $VMName = $nameVer + "-WxVM" + $deviceSuffix.ToString("D2")
    }

#configure VM NIC
    #create a public IP address
    $publicIpName = $VMName.Replace("-","") + "-PIP"
    $pipParams = @{
        ResourceGroupName = $rgName
        Name = $publicIpName
        Location = $location
        AllocationMethod = "Dynamic"
    }
    $PIp = New-AzPublicIpAddress @pipParams
    #Create ipConfig
    $vnet = Get-AzVirtualNetwork -Name ($nameVer + "-VNet") -ResourceGroupName $rgName
    $ipConfigParams = @{
        Name = $nameVer + "IPConfig"
        SubnetId = $vnet.Subnets[0].id
        PublicIpAddressId = $PIp.id
        PrivateIpAddressVersion = "IPv4"
    }
    $IPconfig = New-AzNetworkInterfaceIpConfig @ipConfigParams
    #Create NIC
    $nicName = $VMName.Replace("-","") + "-NIC"
    #validate if nic name exists else increment device suffix
    if (Get-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -ErrorAction SilentlyContinue) {
        Write-Warning "NIC name $nicName already exists - incrementing device suffix"    
        $currentSuffix = $nicName.Substring($nicName.Length - 2)
        $deviceSuffix = [int]$currentSuffix + 1
        $nicName = $nameVer + "-NIC" + $deviceSuffix.ToString("D2")
    }
    $nicParams = @{
        Name = $nicName
        ResourceGroupName = $rgName
        Location = $location
        NetworkSecurityGroupId = $nsg.Id
        IpConfiguration = $IPconfig

    }
    $NIC = New-AzNetworkInterface @nicParams
    #$NIC = get-aznetworkinterface -Name $nicName -ResourceGroupName $rgName

$VMSize = "Standard_DS1_v2"
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsDesktop" -Offer 'Windows-10' -Skus 'win10-22h2-pro' -Version latest
$VirtualMachine | Set-AzVMBootDiagnostic -Disable
New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -DisableIntegrityMonitoring -Verbose
Write-Host "$vmName Created Successfully!> Device credentials: $userName, $password" -f Green
}
New-AzVMWin10 -resourceSuffix "01" -deviceSuffix "01"

<# public IP
$pIpName = $name + "-PublicIP"
$pIP = New-AzPublicIpAddress -Name $pIpName -ResourceGroupName $rgName -Location $location -AllocationMethod "Static" -Sku "Standard"
#$pIP = Get-AzPublicIpAddress -Name $pIpName -ResourceGroupName $rgName

#Create Nic
$nicName = $name + "-NIC"
$nicParams = @{
    Name = $nicName 
    ResourceGroupName = $rgName 
    Location = $location 
    SubnetId = $vnet.Subnets[1].Id 
    PublicIpAddressId = $pip.Id 
    NetworkSecurityGroupId = $nsg.Id
}
$nic = New-AzNetworkInterface @nicParams
#>

#Deploy Resource group Tempaltes
$paramJsonPath = "C:\Temp\Training\Ex_Files_Azure_Admin_Deploy_and_Manage\Exercise Files\parameters.json"
$TemplateJsonPath = "C:\Temp\Training\Ex_Files_Azure_Admin_Deploy_and_Manage\Exercise Files\template.json"
New-AzResourceGroupDeployment -ResourceGroupName "Az104Templates-RG" -TemplateFile $TemplateJsonPath -TemplateParameterFile $paramJsonPath


#Create Scale Set
$ssName = $name + "-SS"
$ssParams = @{
    ResourceGroupName = $rgName
    Location = $location
    VMScaleSetName = $ssName 
    VirtualNetworkName = $VNetName
    SubnetName = "ssSubnet"
    PublicIpAddressName = $pIpName
    UpgradePolicyMode = "Automatic"
    Credential = $vmCred
    ImageName = "Win2016Datacenter"
    InstanceCount = 2
    SecurityGroupName = $nsgName
    VMSize = "Standard_DS1_v2"
    Priority = "Spot"
    MaxPrice = -1
    EvictionPolicy = "Delete"    
    DomainNameLabel = $domainNameLabel
    
}
New-AzVmss @ssParams

#Create availability set
$asName = $name + "-AS"
$asParams = @{
    ResourceGroupName = $rgName
    Name = $asName
    Location = $location
    PlatformFaultDomainCount = 2
    PlatformUpdateDomainCount = 5
    Sku = "Aligned" # "Classic" or "Aligned" for unManaged and Managed disks respectively
    
}
New-AzAvailabilitySet @asParams

#Add VM to an AS
$vmParams = @{
        ResourceGroupName = $rgName
        Location = $location
        VirtualNetworkName = $VNetName
        SecurityGroupName = $nsgName
        AvailabilitySetName = $asName
        ImageName = "Win2016Datacenter"
        Size = "Standard_B1s"
        Credential = $vmCred   
        OpenPorts = 3389  
    }
    New-AzVm @vmParams -Name "AZ104VmAs-Srv01"

#Create VM with Azure Spot - This cannot be combined with Availability Sets
    $vmParams = @{
        ResourceGroupName = $rgName
        Location = $location
        VirtualNetworkName = $VNetName
        SubnetName = "Default"
        SecurityGroupName = $nsgName
        ImageName = "Win2016Datacenter"
        Size = "Standard_DS1_v2"
        Credential = $vmCred   
        OpenPorts = 3389
        Priority = "Spot"
        MaxPrice = -1
        EvictionPolicy = "Delete"
        DomainNameLabel = $domainNameLabel
    }
    New-AzVm @vmParams -Name "AZ104VmSpot-Srv02"
    
    #Add data disk
        #Variables
        $location = "AustraliaEast"
        $rgName = $name + "-RG"

        $vm = Get-AzVM -Name "AZ104Vm-Srv02" -ResourceGroupName $rgName
        $diskConfig = New-AzDiskConfig -SkuName Standard_LRS -Location $location -CreateOption Empty -DiskSizeGB 128
        $dataDisk = New-AzDisk -DiskName "AZ104Vm-Srv02-DataDisk" -Disk $diskConfig -ResourceGroupName $rgName
        $vm = Add-AzVMDataDisk -VM $vm -Name "AZ104Vm-Srv02-DataDisk" -CreateOption Attach -ManagedDiskId $dataDisk.Id -Lun 1
        Update-AzVM -VM $vm -ResourceGroupName $rgName

    #encrypt VM
        #Create raqndom KeyVault Name
            $labelRegex = '^[a-zA-Z0-9-]{3,24}$'

            # Generate a random string of length between 3 and 24
            $randomName = -join ((65..90) + (97..122) + (48..57) + (45, 45) | Get-Random -Count (Get-Random -Minimum 3 -Maximum 25) | ForEach-Object {[char]$_})
            
            if ($randomName -match $labelRegex) {
                Write-Host "Random name: $randomName"
            } else {
                Write-Host "Failed to generate a valid name."
            }

        $keyVaultName = $randomName + "-KV"
        $keyVaultParams = @{
            ResourceGroupName = $rgName
            Location = $location
            Name = $keyVaultName
            EnabledForDiskEncryption = $true
        }
        $keyVault = New-AzKeyVault @keyVaultParams

        #Encrypt VM
        $vm = Get-AzVM -Name "AZ104Vm-Srv02" -ResourceGroupName $rgName
        $encryptParams = @{
            ResourceGroupName = $rgName
            VmName = $vm.Name
            DiskEncryptionKeyVaultUrl = $keyVault.VaultUri
            DiskEncryptionKeyVaultId = $keyVault.ResourceId
        }
        Set-AzVMDiskEncryptionExtension @encryptParams
        
        
#Create VM with Azure Spot with AzVM cmdlets for more refined control
$VMName = "AZ104Vm-Srv03"
$VMSize = "Standard_DS1_v2"
    #Create Nic
    $nicName = $VMName + "-NIC"
    $nicParams = @{
        Name = $nicName 
        ResourceGroupName = $rgName 
        Location = $location 
        SubnetId = $vnet.Subnets[1].Id 
        PublicIpAddressId = $pip.Id 
        NetworkSecurityGroupId = $nsg.Id
    }
    $nic = New-AzNetworkInterface @nicParams
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -Verbose






<# To reconfigured: Az Firewall
Create az firewall that allows all https traffic
$rule = New-AzFirewallApplicationRule -Name "AllowHTTPS" -Protocol "Https:443" -TargetFqdn "*"
$ruleCollection = New-AzFirewallApplicationRuleCollection -Name "AllowHTTPS" -Priority 100 -Rule $rule -ActionType "Allow"
$pIP = New-AzPublicIpAddress -Name "Az104FW-PublicIP" -ResourceGroupName $rgName -Location $location -AllocationMethod "Static" -Sku "Standard"
$azfwParams = @{
    ResourceGroupName = $rgName
    Name = "Az104-FW"
    Location = $location
    VirtualNetwork = (Get-AzVirtualNetwork -Name "Az104-VNet" -ResourceGroupName $rgName)
    ApplicationRuleCollection = $ruleCollection
    PublicIpAddress = $pIP
}
New-AzFirewall @azfwParams
#>