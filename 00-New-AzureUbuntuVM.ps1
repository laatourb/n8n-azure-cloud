[CmdletBinding()]
param (
    [Parameter()]
    [string]$ResourceGroupName = "n8n-testing-france",

    [Parameter()]
    [string]$Location = "westus2",

    [Parameter()]
    [string]$VNetName = "n8n-vNet",

    [Parameter()]
    [string]$SubnetName = "n8n-subnet",

    [Parameter()]
    [string]$VMName = "n8n-VM",

    [Parameter()]
    [string]$VMSize = "Standard_B2ms",

    [Parameter()]
    [string]$AdminUsername = "bilal",

    [Parameter()]
    [int]$OsDiskSize = 128,
    
    [Parameter()]
    [string]$StorageAccountType = "StandardSSD_LRS",

    [Parameter()]
    [string]$tag = "n8n",

    [Parameter()]
    [string]$VNetAddressPrefix = "10.0.0.0/16",

    [Parameter()]
    [string]$SubnetAddressPrefix = "10.0.0.0/24",

    [Parameter()]
    [secureString]$adminPassword = (Read-Host -AsSecureString "Enter password for $AdminUsername"),

    [Parameter()]
    [switch]$CreateResourceGroup = $false
)

# Define standard tags for all resources
$tags = @{
    "Asset"     = $tag
    "CreatedBy" = "PowerShell"
    "CreatedOn" = (Get-Date).ToString("yyyy-MM-dd")
}

# Vérifier si le groupe de ressources existe, sinon le créer
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    Write-Host "Le groupe de ressources '$ResourceGroupName' n'existe pas. Création en cours..."
    $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag $tags
    Write-Host "Groupe de ressources créé avec succès."
}

# Check for existing VNet or create a new one
$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $vnet) {
    Write-Host "Creating virtual network $VNetName with subnet $SubnetName..."
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
    $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -Location $Location -AddressPrefix $VNetAddressPrefix -Subnet $subnetConfig -Tag $tags
}
else {
    Write-Host "Using existing virtual network $VNetName..."
    # Check if subnet exists
    $subnet = $vnet | Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -ErrorAction SilentlyContinue
    if (-not $subnet) {
        Write-Error "Subnet '$SubnetName' not found in virtual network '$VNetName'."
        return
    }
}

# Get subnet reference
$subnet = $vnet | Get-AzVirtualNetworkSubnetConfig -Name $SubnetName
if (-not $subnet) {
    throw "Subnet '$SubnetName' does not exist in virtual network '$VNetName'."
}

# Create NSG and add rules
$nsgName = "$VMName-nsg"
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $nsg) {
    Write-Host "Creating Network Security Group '$nsgName'..."
    
    # Create NSG first
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
        -Location $Location -Name $nsgName -Tag $tags

    # Create and add rules
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName
    
    # SSH Rule
    $nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
        -Name "Allow-SSH" `
        -Description "Allow SSH" `
        -Protocol Tcp `
        -SourcePortRange * `
        -DestinationPortRange 22 `
        -SourceAddressPrefix * `
        -DestinationAddressPrefix * `
        -Access Allow `
        -Priority 1000 `
        -Direction Inbound

    # HTTP Rule
    $nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
        -Name "Allow-HTTP" `
        -Description "Allow HTTP" `
        -Protocol Tcp `
        -SourcePortRange * `
        -DestinationPortRange 80 `
        -SourceAddressPrefix * `
        -DestinationAddressPrefix * `
        -Access Allow `
        -Priority 1001 `
        -Direction Inbound

    # HTTPS Rule
    $nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
        -Name "Allow-HTTPS" `
        -Description "Allow HTTPS" `
        -Protocol Tcp `
        -SourcePortRange * `
        -DestinationPortRange 443 `
        -SourceAddressPrefix * `
        -DestinationAddressPrefix * `
        -Access Allow `
        -Priority 1002 `
        -Direction Inbound

    # n8n Web Interface
    $nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
        -Name "Allow-n8n-Web" `
        -Description "Allow n8n Web Interface" `
        -Protocol Tcp `
        -SourcePortRange * `
        -DestinationPortRange 5678 `
        -SourceAddressPrefix * `
        -DestinationAddressPrefix * `
        -Access Allow `
        -Priority 1003 `
        -Direction Inbound

    # Portainer
    $nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
        -Name "Allow-Portainer" `
        -Description "Allow Portainer" `
        -Protocol Tcp `
        -SourcePortRange * `
        -DestinationPortRange 9443 `
        -SourceAddressPrefix * `
        -DestinationAddressPrefix * `
        -Access Allow `
        -Priority 1004 `
        -Direction Inbound

    # Portainer API
    $nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
        -Name "Allow-Portainer-API" `
        -Description "Allow Portainer API" `
        -Protocol Tcp `
        -SourcePortRange * `
        -DestinationPortRange 8000 `
        -SourceAddressPrefix * `
        -DestinationAddressPrefix * `
        -Access Allow `
        -Priority 1005 `
        -Direction Inbound

    # Save the NSG configuration
    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg
    Write-Host "NSG rules have been added"
}
else {
    Write-Host "Using existing Network Security Group '$nsgName'..."
    # Check and add rules if they don't exist
    $rules = @(
        @{
            Name = "Allow-SSH"
            Port = 22
            Priority = 1000
        },
        @{
            Name = "Allow-HTTP"
            Port = 80
            Priority = 1001
        },
        @{
            Name = "Allow-HTTPS"
            Port = 443
            Priority = 1002
        },
        @{
            Name = "Allow-n8n-Web"
            Port = 5678
            Priority = 1003
        },
        @{
            Name = "Allow-Portainer"
            Port = 9443
            Priority = 1004
        },
        @{
            Name = "Allow-Portainer-API"
            Port = 8000
            Priority = 1005
        }
    )

    foreach ($rule in $rules) {
        $existingRule = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $rule.Name -ErrorAction SilentlyContinue
        if (-not $existingRule) {
            Write-Host "Adding rule for $($rule.Name)..."
            $nsg = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg `
                -Name $rule.Name `
                -Description "Allow $($rule.Name)" `
                -Protocol Tcp `
                -SourcePortRange * `
                -DestinationPortRange $rule.Port `
                -SourceAddressPrefix * `
                -DestinationAddressPrefix * `
                -Access Allow `
                -Priority $rule.Priority `
                -Direction Inbound
        }
    }
    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg
}

# Create Public IP
$publicIpName = "$VMName-pip"
$publicIp = Get-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $publicIp) {
    Write-Host "Creating Public IP Address '$publicIpName'..."
    $publicIp = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -Name $publicIpName `
        -AllocationMethod Static `
        -Sku Standard `
        -Tag $tags
}

# Check for NIC, create if not exists
$nicName = "$VMName-nic"
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $nic) {
    Write-Verbose "Creating Network Interface '$nicName'..."
    $nic = New-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Location $Location `
        -Name $nicName -SubnetId $subnet.Id -NetworkSecurityGroupId $nsg.Id `
        -PublicIpAddressId $publicIp.Id -Tag $tags
}

# Get latest Ubuntu image version
Write-Host "Finding latest Ubuntu image version..."
$publisher = "Canonical"
$offer = "Ubuntu-25_04"
$sku = "server"
$latestVersion = (Get-AzVMImage -Location $Location -PublisherName $publisher -Offer $offer -Skus $sku | Sort-Object -Property Version -Descending | Select-Object -First 1).Version

# Create VM configuration
Write-Host "Creating VM configuration..."
$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize

# Configure OS settings
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $VMName -Credential (New-Object System.Management.Automation.PSCredential($AdminUsername, $adminPassword))

# Configure VM source image
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisher -Offer $offer -Skus $sku -Version $latestVersion

# Configure OS disk
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -DiskSizeInGB $OsDiskSize -CreateOption FromImage -StorageAccountType $StorageAccountType

# Attach network interface
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Disable boot diagnostics
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if ($vm) {
    Write-Host "VM $VMName already exists. Skipping creation."
    return
}
else {
    # Create the VM
    Write-Host "Creating Ubuntu VM $VMName... (this may take several minutes)"
    $vm = New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vmConfig -Tag $tags
}

if ($vm) {
    Write-Host "VM created successfully!"
    Write-Host "You can connect to the VM using: ssh $AdminUsername@$($publicIp.IpAddress)"
    Write-Host "Password: (the one you entered during VM creation)"
}
