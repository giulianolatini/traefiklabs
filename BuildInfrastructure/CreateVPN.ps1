
# Parameters creation and initialization
[string]$RG = "Traefick"
[string]$Location = "westeurope"
[string]$VNetName  = "VNet1"
[string]$FESubName = "FrontEnd"
[string]$GWSubName = "GatewaySubnet"
[string]$VNetPrefix = "10.1.0.0/16"
[string]$FESubPrefix = "10.1.0.0/24"
[string]$GWSubPrefix = "10.1.255.0/27"
[string]$VPNClientAddressPool = "172.16.201.0/24"
[string]$GWName = "VNet1GW"
[string]$GWIPName = "VNet1GWpip"
[string]$GWIPconfName = "gwipconf"
[string]$DNS = "10.2.1.4"

# Main Script

Get-AzSubscription

Set-AzContext -Subscription "«change this with a subscription id»"

# [Connect to a VNet from a computer - P2S VPN and Azure certificate authentication: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#ConfigureVNet)
New-AzResourceGroup -Name $RG -Location $Location


$fesub = New-AzVirtualNetworkSubnetConfig -Name $FESubName -AddressPrefix $FESubPrefix
$gwsub = New-AzVirtualNetworkSubnetConfig -Name $GWSubName -AddressPrefix $GWSubPrefix

New-AzVirtualNetwork `
   -ResourceGroupName $RG `
   -Location $Location `
   -Name $VNetName `
   -AddressPrefix $VNetPrefix `
   -Subnet $fesub, $gwsub `
   -DnsServer $DNS

$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $RG
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet

$pip = New-AzPublicIpAddress -Name $GWIPName -ResourceGroupName $RG -Location $Location -AllocationMethod Dynamic
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name $GWIPconfName -Subnet $subnet -PublicIpAddress $pip

# [Connect to a VNet from a computer - P2S VPN and Azure certificate authentication: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#creategateway)

New-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RG `
-Location $Location -IpConfigurations $ipconf -GatewayType Vpn `
-VpnType RouteBased -EnableBgp $false -GatewaySku VpnGw1 -VpnClientProtocol "IKEv2"

Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroup $RG

# [Connect to a VNet from a computer - P2S VPN and Azure certificate authentication: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#addresspool)

$Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $RG -Name $GWName
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Gateway -VpnClientAddressPool $VPNClientAddressPool

# [Connect to a VNet from a computer - P2S VPN and Azure certificate authentication: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#Certificates)

# [Generare ed esportare certificati per P2S: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/it-it/azure/vpn-gateway/vpn-gateway-certificates-point-to-site)

# [Generare ed esportare certificati per P2S: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/it-it/azure/vpn-gateway/vpn-gateway-certificates-point-to-site#create-a-self-signed-root-certificate)
$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

# [Generare ed esportare certificati per P2S: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/it-it/azure/vpn-gateway/vpn-gateway-certificates-point-to-site#generate-a-client-certificate)
New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
-Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" `
-Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# [Generare ed esportare certificati per P2S: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/it-it/azure/vpn-gateway/vpn-gateway-certificates-point-to-site#export-the-root-certificate-public-key-cer)
# [Generare ed esportare certificati per P2S: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/it-it/azure/vpn-gateway/vpn-gateway-certificates-point-to-site#export-the-client-certificate)
# [Connessione a una rete virtuale da un computer - VPN P2S e autenticazione del certificato di Azure: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/it-it/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#upload-root-certificate-public-key-information)

# [Connect to a VNet using P2S VPN & certificate authentication: portal - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal#uploadfile)
Get-Content .\P2SRootCert.cer | clip
$P2SRootCertName = "P2SRootCert.cer"
$filePathForCert = "C:\TEMP\P2SRootCert.cer"
$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($filePathForCert)
$CertBase64 = [system.convert]::ToBase64String($cert.RawData)
Add-AzVpnClientRootCertificate -VpnClientRootCertificateName $P2SRootCertName -VirtualNetworkGatewayname $GWName -ResourceGroupName $RG -PublicCertData $CertBase64
# [Connessione a una rete virtuale da un computer - VPN P2S e autenticazione del certificato di Azure: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/it-it/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#to-generate-configuration-files)
$profile=New-AzVpnClientConfiguration -ResourceGroupName $RG -Name $GWName -AuthenticationMethod "EapTls"

$profile.VPNProfileSASUrl

# [Connect to a VNet from a computer - P2S VPN and Azure certificate authentication: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#verify)

# [Connect to a VNet from a computer - P2S VPN and Azure certificate authentication: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps#connectVM)

# Create a public IP address and specify a DNS name
$pip = New-AzPublicIpAddress `
  -ResourceGroupName $RG `
  -Location $Location `
  -AllocationMethod Static `
  -IdleTimeoutInMinutes 4 `
  -Name "trafeik01"

$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
  -Name "TraefikAccessHTTP"  `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority 1001 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80 `
  -Access "Allow"
$nsgRuleHTTPS = New-AzNetworkSecurityRuleConfig `
  -Name "TraefikAccessHTTPS"  `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority 1002 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 443 `
  -Access "Allow"

$nsg = New-AzNetworkSecurityGroup `
  -ResourceGroupName $RG `
  -Location $Location `
  -Name "TraefikSecurityGroup" `
  -SecurityRules $nsgRuleHTTP, $nsgRuleHTTPS 

$NICName = "nic01_docker01"
  
$NIC = New-AzNetworkInterface `
  -Name $NICName `
  -ResourceGroupName $RG `
  -Location $Location `
  -SubnetId $vnet.Subnets[0].Id `
  -PublicIpAddressId $pip.Id `
  -NetworkSecurityGroupId $nsg.Id

$ComputerName = "docker01"
$VMName = "docker01"
$VMSize = "Standard_DS3"

# Define a credential object
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

# Create a virtual machine configuration
$vmConfig = New-AzVMConfig `
  -VMName $VMName `
  -VMSize $VMSize | `
Set-AzVMOperatingSystem `
  -Linux `
  -ComputerName $ComputerName `
  -Credential $cred `
  -DisablePasswordAuthentication | `
Set-AzVMSourceImage `
  -PublisherName "zerto" `
  -Offer "azure-vms-by-zerto" `
  -Skus "ubuntu1804lts-python-docker-zerto" `
  -Version "1.0.0" | `
Add-AzVMNetworkInterface `
  -Id $NIC.Id

# Configure the SSH key
$sshPublicKey = cat .ssh/myaccesskey.pub
Add-AzVMSshPublicKey `
  -VM $vmconfig `
  -KeyData $sshPublicKey `
  -Path "/home/azureuser/.ssh/authorized_keys"

New-AzVM `
  -ResourceGroupName $RG `
  -Location $Location -VM $vmConfig

# [Create a route-based virtual network gateway: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/create-routebased-vpn-gateway-powershell#viewgw)
#Get-AzVirtualNetworkGateway -Name Vnet1GW -ResourceGroup $RG

# [Create a route-based virtual network gateway: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/create-routebased-vpn-gateway-powershell#viewgwpip)
#Get-AzPublicIpAddress -Name VNet1GWIP -ResourceGroupName $RG

# [Create a route-based virtual network gateway: PowerShell - Azure VPN Gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/create-routebased-vpn-gateway-powershell#clean-up-resources)
#Remove-AzResourceGroup -Name $RG

# Clean Parameter from scope
#Remove-Variable RG
#Remove-Variable Location
#Remove-Variable VNetName
#Remove-Variable FESubName
#Remove-Variable GWSubName
#Remove-Variable VNetPrefix
#Remove-Variable FESubPrefix
#Remove-Variable GWSubPrefix
#Remove-Variable VPNClientAddressPool
#Remove-Variable GWName
#Remove-Variable GWIPName
#Remove-Variable GWIPconfName
#Remove-Variable DNS
#Remove-Variable P2SRootCertName
#Remove-Variable filePathForCert
#Remove-Variable CertBase64
#Remove-Variable profile
