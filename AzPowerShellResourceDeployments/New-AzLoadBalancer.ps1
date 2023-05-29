$NewResourceName = "Demo"
#set-execution policy
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#variables
Write-Progress "Setting variables" -Status "Please wait..."
    $name = $NewResourceName
    $location = 'Australia East'
    $AddressPrefix16 = "10.0.0.0/16"
    $AddressPrefix240 = $AddressPrefix16.Replace("0.0/16","0.0/24") # Bastian
    $AddressPrefix241 = $AddressPrefix16.Replace("0.0/16","1.0/24") # FrontEnd
    $AddressPrefix242 = $AddressPrefix16.Replace("0.0/16","2.0/24") # BackEnd   
    $rgName = $name + "-RG"

    #connect Az
    Write-Progress "Checking if Az module is installed" -Status "Please wait..."
    if (Get-AzSubscription -SubscriptionName 'Azure subscription 1' -ErrorAction SilentlyContinue) {
        Write-Progress "Confirmed connected to Azure" -Status "proceeding..."
    } else {
        Write-Progress -Activity "Connecting to Azure" -Status "Please wait..."
        Connect-AzAccount
    }
    $Azcontext = Set-AzContext -Subscription 'Azure subscription 1'
    
#Create resource group
Write-Progress -Activity "Creating Resource Group" -Status "Please wait..."
    $rg = New-AzResourceGroup -Name $rgName -Location $location
    Write-Host "New Resource Group: $rgName" -f Green
     
#Create Subnets
    #Create AzureBastionSubnet
    Write-Progress -Activity "Creating Subnets" -Status "creating azure bastion subnet..."
        $BastionSubnetName = "AzureBastionSubnet"
        $subnetParams = @{
            name = $BastionSubnetName
            addressPrefix = $AddressPrefix240
        }
        $subnetBastion = New-AzVirtualNetworkSubnetConfig @subnetParams
    
    #Create FrontEndSubnet
    Write-Progress -Activity "Creating Subnets" -Status "creating FrontEnd subnet..."
    $FrontSubnetName = $name + "FrontEndSubnet"
    $subnetParams = @{
        name = $FrontSubnetName
        addressPrefix = $AddressPrefix241
    }
    $subnetFrontEnd = New-AzVirtualNetworkSubnetConfig @subnetParams

    #Create anohter BackEndSubnet
    Write-Progress -Activity "Creating Subnets" -Status "creating BackEnd subnet..."
    $BackSubnetName = $name + "BackEndSubnet"
    $subnetParams = @{
        name = $BackSubnetName
        addressPrefix = $AddressPrefix242
    }
    $subnetBackEnd = New-AzVirtualNetworkSubnetConfig @subnetParams 
        
# Create Vnet
    Write-Progress -Activity "Creating Virtual Network" -Status "Please wait..."
    $VNetName = $name + "-VNet"
    $vnetParams = @{
        ResourceGroupName = $rgName
        Name = $VNetName
        Location = $location
        AddressPrefix = $AddressPrefix16
        Subnet = $subnetBastion, $subnetFrontEnd, $subnetBackEnd
    }
    $vNet = New-AzVirtualNetwork @vnetParams
    Write-Host "New Virtual Network: $VNetName" -f Green
    
#Create Route Table
Write-Progress -Activity "Creating Route Table" -Status "Please wait..."
$routeTableName = $name + "RT"
$routeTable = New-AzRouteTable -Name $routeTableName -ResourceGroupName $rgName -location $location

    #Set Route Table to FontEnd
    Write-Progress -Activity "Creating FrontEnd Route Table" -Status "Please wait..."
    Get-AzRouteTable -ResourceGroupName $rgName -Name $routeTableName | 
        Add-AzRouteConfig -Name "ToFrontEnd" -AddressPrefix $AddressPrefix241 -NextHopType VnetLocal  | 
            Set-AzRouteTable
    
        # Associate the route table with the subnet
        $rtConfigParams = @{
            VirtualNetwork = $vNet
            Name = ($vNet.subnets | where {$_.Name -like '*Front*'}).name 
            AddressPrefix = ($vNet.subnets | where {$_.Name -like '*Front*'}).AddressPrefix 
            RouteTable = $routeTable
        }
        Set-AzVirtualNetworkSubnetConfig @rtConfigParams | 
            Set-AzVirtualNetwork

    #Set Route Table to BackEnd
    Write-Progress -Activity "Creating BackEnd Route Table" -Status "Please wait..."
    Get-AzRouteTable -ResourceGroupName $rgName -Name $routeTableName | 
        Add-AzRouteConfig -Name "ToBackEnd" -AddressPrefix $AddressPrefix242 -NextHopType VnetLocal  | 
            Set-AzRouteTable

        # Associate the route table with the subnet
        $rtConfigParams = @{
            VirtualNetwork = $vNet
            Name = ($vNet.subnets | where {$_.Name -like '*Back*'}).name 
            AddressPrefix = ($vNet.subnets | where {$_.Name -like '*Back*'}).AddressPrefix 
            RouteTable = $routeTable
        }
        Set-AzVirtualNetworkSubnetConfig @rtConfigParams | 
            Set-AzVirtualNetwork
        
#Create Bastian
    Write-Progress -Activity "Creating Bastian" -Status "Please wait..."
    $bastianJob = start-job -ScriptBlock {
        param($name, $rgName, $vNetName, $location)
        
        #Create public IP address for bastian
        Write-Progress -Activity "Creating Public IP Address" -Status "Please wait..."
        $pIp = New-AzPublicIpAddress -ResourceGroupName $rgName -name ($name + "Bastian-PIP") -location $location -AllocationMethod Static -Sku Standard

        $bastianParams = @{
            
            Name = $name + "-Bastion"
            ResourceGroupName = $rgName
            PublicIpAddressName = $pIp.Name
            PublicIpAddressRgName = $rgName
            VirtualNetworkName = $vNetName
            VirtualNetworkRgName = $rgName
            Sku = "Standard"
        } 
        New-AzBastion @bastianParams

        #Check if burnToast module is installed
        $time = Get-Date
        if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
        $notificationTitle = "Bastian Creation Completed $time"
        $notificationMessage = "The Bastian creation process has been completed."
        $toastHeader = New-BTHeader -Title $notificationTitle
        New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader
    } -Name "CreateBastian" -ArgumentList $name, $rgName, $vNetName, $location
    Write-Host "Initiated job `$bastianJob: Create Azure Bastian."

#Create Load balancer
Write-Progress -Activity "Creating Load Balancer" -Status "Please wait..."
    ## Create public IP address for load balancer and place in variable. ##
    Write-Progress -Activity "Creating Public IP Address" -Status "Please wait..."
    $publicip = @{
        Name = 'Lb-PIP'
        ResourceGroupName = $rgName
        Location = $location
        Sku = 'Standard'
        AllocationMethod = 'static'
    }
    $publicIp = New-AzPublicIpAddress @publicip

    ## Create load balancer frontend configuration and place in variable. ##
    Write-Progress -Activity "Creating Load Balancer Frontend" -Status "Please wait..."
    $fip = @{
        Name = 'LbFrontEndConf'
        PublicIpAddress = $publicIp 
    }
    $feIp = New-AzLoadBalancerFrontendIpConfig @fip

    ## Create backend address pool configuration and place in variable. ##
    Write-Progress -Activity "Creating Load Balancer Backend" -Status "Please wait..."
    $bePool = New-AzLoadBalancerBackendAddressPoolConfig -Name 'LbBackEndPool'

    ## Create the health probe and place in variable. ##
    Write-Progress -Activity "Creating Load Balancer Health Probe" -Status "Please wait..."
    $probe = @{
        Name = 'HealthProbe'
        Protocol = 'tcp'
        Port = '80'
        IntervalInSeconds = '360'
        ProbeCount = '5'
    }
    $healthprobe = New-AzLoadBalancerProbeConfig @probe

    ## Create the load balancer rule and place in variable. ##
    Write-Progress -Activity "Creating Load Balancer Rule" -Status "Please wait..."
    $lbrule = @{
        Name = 'HTTPRule'
        Protocol = 'tcp'
        FrontendPort = '80'
        BackendPort = '80'
        IdleTimeoutInMinutes = '15'
        FrontendIpConfiguration = $feip
        BackendAddressPool = $bePool
    }
    $LbRule = New-AzLoadBalancerRuleConfig @lbrule -EnableTcpReset -DisableOutboundSNAT

    ## Create the load balancer resource. ##
    Write-Progress -Activity "Creating Load Balancer" -Status "Please wait..."
    $lbName = $name + "-LB"
    $loadbalancer = @{
        ResourceGroupName = $rgName
        Name = $lbName
        Location = $location
        Sku = 'Standard'
        FrontendIpConfiguration = $feip
        BackendAddressPool = $bePool
        LoadBalancingRule = $LbRule
        Probe = $healthprobe
    }
    $lb = New-AzLoadBalancer @loadbalancer

#Create NAT Gateway
Write-Progress -Activity "Creating NAT Gateway" -Status "Please wait..."
    ## Create public IP address for NAT gateway ##
    Write-Progress -Activity "Creating Public IP Address" -Status "Please wait..."
    $ip = @{
        Name = 'NATgatewayIP'
        ResourceGroupName = $rgName
        Location = $location
        Sku = 'Standard'
        AllocationMethod = 'Static'
    }
    $publicIP = New-AzPublicIpAddress @ip

    ## Create NAT gateway resource ##
    Write-Progress -Activity "Creating NAT Gateway" -Status "Please wait..."
    $natName = $name + "-NATG"
    $nat = @{
        ResourceGroupName = $rgName
        Name = $natName
        IdleTimeoutInMinutes = '10'
        Sku = 'Standard'
        Location = $location
        PublicIpAddress = $publicIP
    }
    $natGateway = New-AzNatGateway @nat

#Create NSG
Write-Progress -Activity "Creating Network Security Group" -Status "Please wait..."
    ## Create rule for network security group and place in variable. ##
    Write-Progress -Activity "Creating NSG Rule" -Status "Please wait..."
    $nsgrule = @{
        Name = 'NSGRuleHTTP'
        Description = 'Allow HTTP'
        Protocol = '*'
        SourcePortRange = '*'
        DestinationPortRange = '80'
        SourceAddressPrefix = 'Internet'
        DestinationAddressPrefix = '*'
        Access = 'Allow'
        Priority = '2000'
        Direction = 'Inbound'
    }
    $rule1 = New-AzNetworkSecurityRuleConfig @nsgrule

    ## Create network security group ##
    Write-Progress -Activity "Creating Network Security Group" -Status "Please wait..."
    $nsgName = $name + "-NSG"
    $nsg = @{
        Name = $nsgName
        ResourceGroupName = $rgName
        Location = $location
        SecurityRules = $rule1
    }
    $nsg = New-AzNetworkSecurityGroup @nsg


#Create VMs
#$lbBackPool = Get-AzLoadBalancer -name $lbName -ResourceGroupName $rgName | Get-AzLoadBalancerBackendAddressPoolConfig
    #Create Desktop VM with Azure Spot with AzVM cmdlets to disable Monitoring and Diagnostics
    Write-Progress -Activity "Creating VMs" -Status "Initiating Job to create VMs..."
    #Create Job to create VM
    $WxJob = Start-Job -ScriptBlock {
            param(
                $name,
                $rgName,  
                $Location
            )

    #Get VM Credentials from KeyVault
        $kvName = "RT-SecureSpot"
        $kv = Get-AzKeyVault -Name $kvName -ResourceGroupName "SystemAdmin-RG"
        $userName = Get-AzKeyVaultSecret -VaultName $kvName -Name "InstallerLocalAccountName" -AsPlainText
        $password = Get-AzKeyVaultSecret -VaultName $kvName -Name "InstallerLocalAccountSecret" -AsPlainText
        $vmCred = New-Object System.Management.Automation.PSCredential ($userName, (ConvertTo-SecureString $password -AsPlainText -Force))
    
    #Create Device name
        $VMName = $name + "Wx"  + "-VM"
        Write-Progress  -Activity "Creating VMs" -status "Creating $VMName..."
    
    
    #Create ipConfig
        $vnet = Get-AzVirtualNetwork -Name ($name + "-VNet") -ResourceGroupName $rgName
        $ipConfigParams = @{
            Name = $name + "IPConfig"
            SubnetId = ($vnet.Subnets | Where-Object {$_.Name -like "*FrontEnd*"}).Id #$vnet.Subnets[0].id
            #PublicIpAddressId = $PIp.id
            PrivateIpAddressVersion = "IPv4"
        }
        $IPconfig = New-AzNetworkInterfaceIpConfig @ipConfigParams

    #Create NIC
        $nicName = $VMName.Replace("-","") + "-NIC"
        $nicParams = @{
            Name = $nicName
            ResourceGroupName = $rgName
            Location = $location
            IpConfiguration = $IPconfig
        }
        $NIC = New-AzNetworkInterface @nicParams
        
    #VM variables
        $VMSize = "Standard_DS1_v2"
        $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
        $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
        $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsDesktop" -Offer 'Windows-10' -Skus 'win10-22h2-pro' -Version latest
        $VirtualMachine | Set-AzVMBootDiagnostic -Disable
        
    #Create VM
        New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -DisableIntegrityMonitoring -Verbose
        $results =[string]"$vmName Created Successfully!> Device credentials Stored in Kv: $kvName"
        Write-Host $results

    #Check if burnToast module is installed
        $time = Get-Date
        if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
            $notificationTitle = "$($VMName): Creation Completed $time"
            $notificationMessage = $results
            $toastHeader = New-BTHeader -Title $notificationTitle
            New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader
        } -Name "CreateWxVM" -ArgumentList $name, $rgName, $Location
        Write-Host "Initiated Job `$WxJob: Create Desktop VM." 
        #Receive-Job -Job $WxJob -Wait
    
    #Create Server VM with Azure Spot with AzVM cmdlets to disable Monitoring and Diagnostics
    $Srv1Job = Start-Job -ScriptBlock {
        param(
            $name,
            $rgName,  
            $Location
        )
        #Create Server name
        $VMName = $name + "Srv1"  +"-VM" 
        Write-Progress  -Activity "Creating VMs" -status "Creating $VMName..."
    
        #Get VM Credentials from KeyVault
        $kvName = "RT-SecureSpot"
        $kv = Get-AzKeyVault -Name $kvName -ResourceGroupName "SystemAdmin-RG"
        $userName = Get-AzKeyVaultSecret -VaultName $kvName -Name "InstallerLocalAccountName" -AsPlainText
        $password = Get-AzKeyVaultSecret -VaultName $kvName -Name "InstallerLocalAccountSecret" -AsPlainText
        $vmCred = New-Object System.Management.Automation.PSCredential ($userName, (ConvertTo-SecureString $password -AsPlainText -Force))
            
        #configure VM NIC
            #Create ipConfig
            $vnet = Get-AzVirtualNetwork -Name ($name + "-VNet") -ResourceGroupName $rgName
            $ipConfigParams = @{
                Name = $name + "IPConfig"
                SubnetId = ($vnet.Subnets | Where-Object {$_.Name -like "*BackEnd*"}).Id
                #PublicIpAddressId = $PIp.id
                PrivateIpAddressVersion = "IPv4"
            }
            $IPconfig = New-AzNetworkInterfaceIpConfig @ipConfigParams
    
            #Create NIC
            $nicName = $VMName.Replace("-","") + "-NIC"
            $nicParams = @{
                Name = $nicName
                ResourceGroupName = $rgName
                Location = $location
                subnet = ($vnet.Subnets | Where-Object {$_.Name -like "*BackEnd*"})
                IpConfigurationName = $IPconfig.Name
                NetworkSecurityGroup = $nsg
                LoadBalancerBackendAddressPool = $lbBackPool
            }
            $nic = New-AzNetworkInterface @nicParams
        
        # Create VM
            #VM variables
            $VMSize = "Standard_DS1_v2"
            $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
            $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
            $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
            $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
            $VirtualMachine | Set-AzVMBootDiagnostic -Disable
    
            #Create VM
                New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -DisableIntegrityMonitoring
                $results =[string]"$vmName Created Successfully!> Device credentials Stored in Kv: $kvName"
                Write-Host $results
            
            #Check if burnToast module is installed
            $time = Get-Date
            if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
            $notificationTitle = "$($VMName): Creation Completed $time"
            $notificationMessage = $results
            $toastHeader = New-BTHeader -Title $notificationTitle
            New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader
            Start-Sleep -Seconds 10

        ## install custom script extension on virtual machines. ##
            $ext = @{
                Publisher = 'Microsoft.Compute'
                ExtensionType = 'CustomScriptExtension'
                ExtensionName = 'IIS'
                ResourceGroupName = $rgName
                VMName = "LBSrv1-VM"
                Location = $location
                TypeHandlerVersion = '1.8'
                SettingString = '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
            }
            try {
                Set-AzVMExtension @ext
                $results =[string]"$vmName Custom Script Extention Installed Successfully!"
            } catch {
                throw
                $results =[string]"$vmName Custom Script Extention deployment failed!" 
            }
            Write-Host $results

            #Check if burnToast module is installed
            $time = Get-Date
            if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
            $notificationTitle = "$($VMName): Custom Script Job Completed $time"
            $notificationMessage = $results
            $toastHeader = New-BTHeader -Title $notificationTitle
            New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader
    
            
        } -Name "CreateSrv1VM" -ArgumentList $name, $rgName, $Location
        Write-Host "Initiated Job `$Srv1Job: Create Server VM."
        #Receive-Job -Job $Srv1Job -Wait -AutoRemoveJob

    $Srv2Job = Start-Job -ScriptBlock {
        param(
            $name,
            $rgName,  
            $Location
        )
        #Create Server name
        $VMName = $name + "Srv2"  +"-VM" 
        Write-Progress  -Activity "Creating VMs" -status "Creating $VMName..."
    
        #Get VM Credentials from KeyVault
        $kvName = "RT-SecureSpot"
        $kv = Get-AzKeyVault -Name $kvName -ResourceGroupName "SystemAdmin-RG"
        $userName = Get-AzKeyVaultSecret -VaultName $kvName -Name "InstallerLocalAccountName" -AsPlainText
        $password = Get-AzKeyVaultSecret -VaultName $kvName -Name "InstallerLocalAccountSecret" -AsPlainText
        $vmCred = New-Object System.Management.Automation.PSCredential ($userName, (ConvertTo-SecureString $password -AsPlainText -Force))
            
        #configure VM NIC
            #Create ipConfig
            $vnet = Get-AzVirtualNetwork -Name ($name + "-VNet") -ResourceGroupName $rgName
            $ipConfigParams = @{
                Name = $name + "IPConfig"
                SubnetId = ($vnet.Subnets | Where-Object {$_.Name -like "*BackEnd*"}).Id
                #PublicIpAddressId = $PIp.id
                PrivateIpAddressVersion = "IPv4"
            }
            $IPconfig = New-AzNetworkInterfaceIpConfig @ipConfigParams
    
            #Create NIC
            $nicName = $VMName.Replace("-","") + "-NIC"
            $nicParams = @{
                Name = $nicName
                ResourceGroupName = $rgName
                Location = $location
                subnet = ($vnet.Subnets | Where-Object {$_.Name -like "*BackEnd*"})
                IpConfigurationName = $IPconfig.Name
                NetworkSecurityGroup = $nsg
                LoadBalancerBackendAddressPool = $lbBackPool
            }
            $nic = New-AzNetworkInterface @nicParams
    
            #VM variables
            $VMSize = "Standard_DS1_v2"
            $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
            $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
            $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
            $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
            $VirtualMachine | Set-AzVMBootDiagnostic -Disable
    
            #Create VM
                New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -DisableIntegrityMonitoring
                $results =[string]"$vmName Created Successfully!> Device credentials Stored in Kv: $kvName"
                Write-Host $results
    
            #Check if burnToast module is installed
            $time = Get-Date
            if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
            $notificationTitle = "$($VMName): Creation Completed $time"
            $notificationMessage = $results
            $toastHeader = New-BTHeader -Title $notificationTitle
            New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader
            Start-Sleep -Seconds 10

        ## install custom script extension on virtual machines. ##
            $ext = @{
                Publisher = 'Microsoft.Compute'
                ExtensionType = 'CustomScriptExtension'
                ExtensionName = 'IIS'
                ResourceGroupName = $rgName
                VMName = "LBSrv2-VM"
                Location = $location
                TypeHandlerVersion = '1.8'
                SettingString = '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
            }
            try {
                Set-AzVMExtension @ext
                $results =[string]"$vmName Custom Script Extention Installed Successfully!"
            } catch {
                throw
                $results =[string]"$vmName Custom Script Extention deployment failed!" 
            }
            Write-Host $results
            
            #Check if burnToast module is installed
            $time = Get-Date
            if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
            $notificationTitle = "$($VMName): Custom Script Job Completed $time"
            $notificationMessage = $results
            $toastHeader = New-BTHeader -Title $notificationTitle
            New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader
        } -Name "CreateSrv2VM" -ArgumentList $name, $rgName, $Location
        Write-Host "Initiated Job `$Srv2Job: Create Server VM."
        #Receive-Job -Job $Srv2Job -Wait -AutoRemoveJob

#CleanUp
$rgName = "LB-RG"
$cleanUpJob = Start-Job -ScriptBlock {
    param(
        $rgName
    )
    Write-Progress -Activity "Cleaning Up" -Status "Please wait..."
    Write-Host "Removing Resource Group: $rgName" -f Green

    try {
        Remove-AzResourceGroup -Name $rgName -Force
        $results =[string]"$rgName Resource group removed Successfully!"
    } catch {
        throw
        $results =[string]"$vmName Resource group removal failed!" 
    }
    Write-Host $results
    
    #Check if burnToast module is installed
    $time = Get-Date
    if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
    $notificationTitle = "$($rgName): Resource group removal Job Completed $time"
    $notificationMessage = $results
    $toastHeader = New-BTHeader -Title $notificationTitle
    New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader

    
} -Name "CleanUp" -ArgumentList $rgName
