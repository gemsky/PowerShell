<#
.SYNOPSIS
    This script will create a new resource group, virtual network, network security group, public ip address, network interface and virtual machine.
.DESCRIPTION
    This Script will start with:
        1. Set-VariablesFroVMs
        2. New-AzResourceGroupScript
        3. New-AzNetworkresources
        4. New-AzVMscript
.LINK
.NOTES
    Version:        1.0
#>

function Set-VariablesFroVMs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Provide new resource naming convention.")]
        [String]
        $NewResourceName
    )
#set-execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#variables
$global:name = $NewResourceName
$global:location = "Australia East"
$global:rgName = $name + "-RG"
} Set-VariablesFroVMs -NewResourceName "Nsg"

function New-AzResourceGroupForVMs {
#set-execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Progress -Activity "Creating Resource Group" -Status "Please wait..."
#connect Az
if (Get-AzSubscription -SubscriptionName 'Azure subscription 1' -ErrorAction SilentlyContinue) {
    Write-Host "Confirmed connected to Azure"
} else {
    Write-Progress -Activity "Connecting to Azure" -Status "Please wait..."
    Connect-AzAccount
}
Set-AzContext -Subscription 'Azure subscription 1'

#Check if variables exist else run Set-VariablesFroVMs
if ($name -eq $null -and $location -eq $null -and $rgName -eq $null) {
    Set-VariablesFroVMs
}

#Create resource group
$global:rgName = $name + "-RG"
$global:rg = New-AzResourceGroup -Name $rgName -Location $location

Write-Host "New Resource Group: $rgName" 

} New-AzResourceGroupForVMs

function New-AzNetworkresourcesForVMs {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True, HelpMessage = "Provide resource version id: 0 - 10.")]
    [String]
    $resourceSuffix
)
#set-execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$global:resourceSuffix = $resourceSuffix

#connect Az
if (Get-AzSubscription -SubscriptionName 'Azure subscription 1' -ErrorAction SilentlyContinue) {
    Write-Progress "Confirmed connected to Azure"
} else {
    Write-Progress -Activity "Connecting to Azure" -Status "Please wait..."
    Connect-AzAccount
}
Set-AzContext -Subscription 'Azure subscription 1'

#Check if variables exist else run Set-VariablesFroVMs
if ($global:name -eq $null -and $global:location -eq $null -and $global:rgName -eq $null) {
    Set-VariablesFroVMs
}

#if resource group does not exist create it
$rgName = $name + "-RG"
if ($global:rgName -eq $null) {
    New-AzResourceGroupScript
}

#Resource Naming convention
$global:nameVer = $name + $resourceSuffix

#Subnet generation
    # Generate a random subnet within the range of 10.0.0.0/16
    function Get-RandomSubnet {
        $randomOctet = Get-Random -Minimum 1 -Maximum 256
        $subnet = "10.{0}.0.0/16" -f $randomOctet
        return $subnet
    } 

#variables
$global:AddressPrefix16 = Get-RandomSubnet
$global:AddressPrefix240 = "10.0.0.0/24" # Bastian  
$global:AddressPrefix241 = $AddressPrefix16.Replace("0.0/16","1.0/24") # FrontEnd
$global:AddressPrefix242 = $AddressPrefix16.Replace("0.0/16","2.0/24") # BackEnd
 
#Create network Security Group
    #Create NSG Rule to allow port 3389
    $nsgRuleParams = @{
        Name = 'NsgRuleRDP'  
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
    #Create NSG Rule to allow port 80
    $nsgRuleParams = @{
        Name = 'NsgRuleHTTP'
        Protocol = 'Tcp'
        Direction = 'Inbound'
        Priority = '1001'
        SourceAddressPrefix = '*'
        SourcePortRange = '*'
        DestinationAddressPrefix = '*'
        DestinationPortRange = 80
        Access = 'allow'
        }
        $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig @nsgRuleParams
        
    #create NSG and add rules
        $global:nsgName = $nameVer + "-NSG"
        $nsgParams = @{
            ResourceGroupName = $rgName
            Name = $nsgName
            Location = $location
            SecurityRules = $nsgRuleHTTP,$nsgRuleRDP
        }   
        $global:nsg = New-AzNetworkSecurityGroup @nsgParams

#Create FrontEndSubnet
$global:FrontSubnetName = $nameVer + "FrontEndSubnet"
$subnetParams = @{
    name = $FrontSubnetName
    addressPrefix = $AddressPrefix241
    NetworkSecurityGroup = $nsg
}
$global:subnetFrontEnd = New-AzVirtualNetworkSubnetConfig @subnetParams

#Create anohter BackEndSubnet
$global:BackSubnetName = $nameVer + "BackEndSubnet"
$subnetParams = @{
    name = $BackSubnetName
    addressPrefix = $AddressPrefix242
    NetworkSecurityGroup = $nsg
}
$global:subnetBackEnd = New-AzVirtualNetworkSubnetConfig @subnetParams 
#Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vNet

# Create Vnet
$global:VNetName = $nameVer + "-VNet"
$vnetParams = @{
    ResourceGroupName = $rgName
    Name = $VNetName
    Location = $location
    AddressPrefix = $AddressPrefix16
    Subnet = $subnetFrontEnd, $subnetBackEnd
}
$global:vNet = New-AzVirtualNetwork @vnetParams
#$vNet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $rgName

Write-Host "New Virtual Network: $VNetName"
} 
    New-AzNetworkresourcesForVMs -resourceSuffix "1"
    New-AzNetworkresourcesForVMs -resourceSuffix "2"

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
New-AzVMWinSrv2016 -resourceSuffix "02" -deviceSuffix "02"


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
New-AzVMWin10 -resourceSuffix "02" -deviceSuffix "02"
#
Start-Job -ScriptBlock {New-AzVMWin10 -resourceSuffix "01" -deviceSuffix "01"}
Start-Job -ScriptBlock {New-AzVMWin10 -resourceSuffix "02" -deviceSuffix "02"}


#How to get GetSourceImage info for Set-AzVMSourceImage
function Get-sourceImageInfo {
    $location = "Australia East" #Read-Host "Enter Azure Location:"
    $PublisherName = Get-AzVMImagePublisher -Location $location | Where-Object {$_.PublisherName -like "*Microsoft*"} | Out-GridView -PassThru -Title "Select PublisherName" 
    $Offer = Get-AzVMImageOffer -Location $location -PublisherName $PublisherName.PublisherName | Out-GridView -PassThru -Title "Select Windows"
    $SKU = Get-AzVMImageSku -Location $location -PublisherName $PublisherName.PublisherName -Offer $Offer.Offer | Out-GridView -PassThru -Title "Select Windows Version"

    #results
    Write-Host "PublisherName: $($PublisherName.PublisherName)" -f Green
    Write-Host "Offer: $($Offer.Offer)" -f Green
    Write-Host "Skus: $($SKU.Skus)" -f Green
}
Get-sourceImageInfo

function New-AzRouteTableForVMs {
#Create Route Table
$routeTableName = $name + "RT"
$routeTable = New-AzRouteTable -Name $routeTableName -ResourceGroupName $rgName -location $location

    #Set Route Table
    Get-AzRouteTable -ResourceGroupName $rgName -Name $routeTableName | 
        Add-AzRouteConfig -Name "FromFrontToBackSubnet" -AddressPrefix $AddressPrefix241 -NextHopType VnetLocal  | 
            Set-AzRouteTable

    # Associate the route table with the subnet
    Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork -Name 'Test01FrontEndSubnet' -AddressPrefix $AddressPrefix241 -RouteTable $routeTable | 
        Set-AzVirtualNetwork

<#Create Route config
$rtParams = @{
    Name = $name + "RouteConfig"
    AddressPrefix = "0.0.0.0/0"
    NextHopType = "VirtualNetworkGateway"
}
$route = New-AzRouteConfig @rtParams

    #Create Route table
    $rtName = $name + "RT"
    $rtParams = @{
        ResourceGroupName = $rgName
        Name = $rtName
        Location = $location
        Route = $route
    }
    $rt = New-AzRouteTable @rtParams

    #Associate Route table with subnet
    $subnetFrontEnd | Set-AzVirtualNetworkSubnetConfig -RouteTable $rt -AddressPrefix $AddressPrefix241
#>
} 
New-AzRouteTableForVMs

function New-AzNetPeeringForVNets {
    function New-Peering {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]
            $vNetName1,
            [Parameter(Mandatory = $true)]
            [string]
            $vNetName2
        )
        #Create network peerings
        $vNet1 = Get-AzVirtualNetwork -Name $vNetName1
        $vNet2 = Get-AzVirtualNetwork -Name $vNetName2
        $peerName = $vNetName1.Replace("-","") + "To" + $vNetName2.Replace("-","")
        $peerParams = @{
            Name = $peerName
            VirtualNetwork = $vNet1
            remoteVirtualNetworkId = $vNet2.Id
            AllowForwardedTraffic = $true
            AllowGatewayTransit = $true
            UseRemoteGateways = $false
        }
        return $peer = Add-AzVirtualNetworkPeering @peerParams
        Write-Host "Created peering $($peer.Name) between $($vNet1.Name) and $($vNet2.Name)"
    }
    $vNets = (Get-AzVirtualNetwork).Name
    #if more than 3 vnets detected = prompt user to select which 2 vnets to peer
    if ($vNets.Count -gt 2) {
        $vNets = $vNets | Out-GridView -PassThru -Title "Select 2 VNets to peer"
    }
    $vNets[0]
    $vNets[1]
    New-Peering -vNetName1 $vNets[0] -vNetName2 $vNets[1] #this needs to be captured manually
    New-Peering -vNetName1 $vNets[1] -vNetName2 $vNets[0] #this needs to be captured manually
}
New-AzNetPeeringForVNets

function New-AzDnsZoneForVMs {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Create a private or public dns zone.")]
    [switch]
    $Public
)

# create a private dns zone
$dnsZoneName = $name + "PrivateDNSZone.com"
$dnsZoneParams = @{
    ResourceGroupName = $rgName
    Name = $dnsZoneName
}   
$dnsZone = New-AzPrivateDnsZone @dnsZoneParams

#if Public switch triggered create public dns zone
    if ($Public) {
        # Create a public dns zone
        $dnsZoneName = $name + "PublicDNSZone.com"
        $dnsZoneParams = @{
            ResourceGroupName = $rgName
            Name = $dnsZoneName
        }
        $dnsZone = New-AzDnsZone @dnsZoneParams

            #Create a record set
            $Records = @()
            $Records += New-AzDnsRecordConfig -Cname www.contoso.com
            $recordSetParams = @{
                Name = "www" 
                RecordType = "CNAME" 
                ResourceGroupName = "MyResourceGroup" 
                TTL = 3600 
                ZoneName = $dnsZoneName
                DnsRecords = $Records
            }
            $RecordSet = New-AzDnsRecordSet @recordSetParams
    }
}
New-AzDnsZoneForVMs
    
function New-AzNsgForVMs {
#Create network Security Group
    #Create NSG Rule allow rdp
    $nsgRuleParams = @{
        Name = 'inBoundAllowRDP'  
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
    
    #Create NSG Rule allow https
    $nsgRuleParams = @{
        Name = 'inBoundAllowHTTPS'
        Protocol = 'Tcp'
        Direction = 'Inbound'
        Priority = '1001'
        SourceAddressPrefix = '*'
        SourcePortRange = '*'
        DestinationAddressPrefix = '*'
        DestinationPortRange = 443
        Access = 'allow'
        }
        $nsgRuleHTTPS = New-AzNetworkSecurityRuleConfig @nsgRuleParams

    #create NSG and add rules
        $nsgName = $name + "NSG"
        $nsgParams = @{
            ResourceGroupName = $rgName
            Name = $nsgName
            Location = $location
            SecurityRules = $nsgRuleRDP, $nsgRuleHTTPS
        }   
        $nsg = New-AzNetworkSecurityGroup @nsgParams
    
    Set-AzVirtualNetworkSubnetConfig -Name 'Test02FrontEndSubnet' -VirtualNetwork $VNet -AddressPrefix "10.0.1.0/24" -NetworkSecurityGroupId $nsg.Id

    $virtualNetwork | Set-AzVirtualNetwork
}
New-AzNsgForVMs

function New-AzBastianForVMs {
    #Create Azure bastion
    $bastionSubnet = Get-AzVirtualNetworkSubnetConfig -Name 'AzureBastionSubnet' -VirtualNetwork $VNet
    $bastionSubnet | Set-AzVirtualNetworkSubnetConfig -AddressPrefix "10.0.1.0/24" -VirtualNetwork $VNet
    $VNet | Set-AzVirtualNetwork
}
New-AzBastianForVMs

#Delete Resource Group
# Remove-AzResourceGroup -Name $rgName -Force