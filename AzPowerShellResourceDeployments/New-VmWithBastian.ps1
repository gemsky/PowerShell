function New-VmsWithBastian {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the name of the new resource", Position = 0)]
    [string]
    $NewResourceName
)

#$NewResourceName = "Test"
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
    Set-AzContext -Subscription 'Azure subscription 1'

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

#Create public IP address for bastian
    Write-Progress -Activity "Creating Public IP Address" -Status "Please wait..."
    $pIp = New-AzPublicIpAddress -ResourceGroupName $rgName -name ($vNetName + "Bastian-PIP") -location $location -AllocationMethod Static -Sku Standard
    
#Create Bastian
    Write-Progress -Activity "Creating Bastian" -Status "Please wait..."
    $bastianJob = start-job -ScriptBlock {
        param($rgName, $vNetName)
        $pIP = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name ($vNetName + "Bastian-PIP")   
        $bastianParams = @{
            
            Name = $vNetName + "Bastion"
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
    } -Name "CreateBastian" -ArgumentList $rgName, $vNetName
    Write-Host "Initiated job `$bastianJob: Create Azure Bastian."

#Create Desktop VM with Azure Spot with AzVM cmdlets to disable Monitoring and Diagnostics
    Write-Progress -Activity "Creating VMs" -Status "Initiating Job to create VMs..."
    #Create Job to create VM
    $WxJob = Start-Job -ScriptBlock {
        param(
            $name,
            $rgName,  
            $Location
        )
    #VM Credentials
    $userName = $name + "4dm1n"
    $password = $name + "4dm1n2023"
    $vmCred = New-Object System.Management.Automation.PSCredential ($userName, (ConvertTo-SecureString $password -AsPlainText -Force))

    #Create Device name
    $VMName = $name + "Wx"  + "-VM"
    Write-Progress  -Activity "Creating VMs" -status "Creating $VMName..."

    #configure VM NIC
        <#create a public IP address
        $publicIpName = $VMName.Replace("-","") + "-PIP"
        $pipParams = @{
            ResourceGroupName = $rgName
            Name = $publicIpName
            Location = $location
            AllocationMethod = "Dynamic"
        }
        $PIp = New-AzPublicIpAddress @pipParams #>

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
        #$NIC = get-aznetworkinterface -Name $nicName -ResourceGroupName $rgName
    
    #VM variables
    $VMSize = "Standard_DS1_v2"
    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Priority "Spot" -MaxPrice -1 -EvictionPolicy Deallocate
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $vmCred -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsDesktop" -Offer 'Windows-10' -Skus 'win10-22h2-pro' -Version latest
    $VirtualMachine | Set-AzVMBootDiagnostic -Disable
    
    #Create VM
        New-AzVM -ResourceGroupName $rgName -Location $Location -VM $VirtualMachine -DisableIntegrityMonitoring -Verbose
        $results =[string]"$vmName Created Successfully!> Device credentials: $userName, $password"
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
    $SrvJob = Start-Job -ScriptBlock {
    param(
        $name,
        $rgName,  
        $Location
    )
    #Create Server name
    $VMName = $name + "Srv"  +"-VM" 
    Write-Progress  -Activity "Creating VMs" -status "Creating $VMName..."

    #VM Credentials
    $userName = $name + "4dm1n"
    $password = $name + "4dm1n2023"
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
            IpConfiguration = $IPconfig
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
            $results =[string]"$vmName Created Successfully!> Device credentials: $userName, $password"
            Write-Host $results

        #Check if burnToast module is installed
        $time = Get-Date
        if (!(Get-Module -Name BurntToast)) { Install-Module -Name BurntToast -Scope CurrentUser }
        $notificationTitle = "$($VMName): Creation Completed $time"
        $notificationMessage = $results
        $toastHeader = New-BTHeader -Title $notificationTitle
        New-BurntToastNotification -Text $notificationMessage -Sound 'Default' -Header $toastHeader
    } -Name "CreateSrvVM" -ArgumentList $name, $rgName, $Location
    Write-Host "Initiated Job `$SrvJob: Create Server VM."
    #Receive-Job -Job $SrvJob -Wait -AutoRemoveJob

} #end of function
New-VmsWithBastian -NewResourceName "Demo"









