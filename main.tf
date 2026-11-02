# ==============================================================================
# Enterprise Azure CAF Landing Zone - Production Infrastructure
# Architect: Ramneek Shriwadi (Lead DevSecOps Engineer & Cloud Architect)
# ==============================================================================

# Resource Group for Central Hub Networking
resource "azurerm_resource_group" "rg_hub" {
  name     = "${var.enterprise_prefix}-rg-hub-${var.environment}"
  location = var.primary_location
  tags     = var.tags
}

# Resource Group for Workload Application Spoke
resource "azurerm_resource_group" "rg_spoke_app" {
  name     = "${var.enterprise_prefix}-rg-spoke-app-${var.environment}"
  location = var.primary_location
  tags     = var.tags
}

# ------------------------------------------------------------------------------
# 1. Central Hub Virtual Network & Subnets
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "${var.enterprise_prefix}-vnet-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.rg_hub.name
  location            = azurerm_resource_group.rg_hub.location
  address_space       = [var.hub_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "azure_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_cidr]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

resource "azurerm_subnet" "hub_shared" {
  name                 = "snet-hub-shared-services"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_vnet_cidr, 8, 2)]
}

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall_pip" {
  name                = "${var.enterprise_prefix}-pip-afw-${var.environment}"
  resource_group_name = azurerm_resource_group.rg_hub.name
  location            = azurerm_resource_group.rg_hub.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Azure Firewall Policy with Intrusion Detection (IDPS)
resource "azurerm_firewall_policy" "afw_policy" {
  name                     = "${var.enterprise_prefix}-afw-policy-${var.environment}"
  resource_group_name      = azurerm_resource_group.rg_hub.name
  location                 = azurerm_resource_group.rg_hub.location
  sku                      = "Premium"
  threat_intelligence_mode = "Deny"

  intrusion_detection {
    mode = "Deny"
  }

  tags = var.tags
}

# Azure Firewall Premium Deployment
resource "azurerm_firewall" "afw" {
  name                = "${var.enterprise_prefix}-afw-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.rg_hub.name
  location            = azurerm_resource_group.rg_hub.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.afw_policy.id

  ip_configuration {
    name                 = "firewall-ip-config"
    subnet_id            = azurerm_subnet.azure_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# 2. Application Workload Spoke Virtual Network
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke_app" {
  name                = "${var.enterprise_prefix}-vnet-spoke-app-${var.environment}"
  resource_group_name = azurerm_resource_group.rg_spoke_app.name
  location            = azurerm_resource_group.rg_spoke_app.location
  address_space       = [var.app_spoke_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "app_tier" {
  name                 = "snet-app-tier"
  resource_group_name  = azurerm_resource_group.rg_spoke_app.name
  virtual_network_name = azurerm_virtual_network.spoke_app.name
  address_prefixes     = [cidrsubnet(var.app_spoke_vnet_cidr, 8, 1)]
}

resource "azurerm_subnet" "db_tier" {
  name                 = "snet-db-tier"
  resource_group_name  = azurerm_resource_group.rg_spoke_app.name
  virtual_network_name = azurerm_virtual_network.spoke_app.name
  address_prefixes     = [cidrsubnet(var.app_spoke_vnet_cidr, 8, 2)]
}

# ------------------------------------------------------------------------------
# 3. Bidirectional VNet Peering (Hub <-> Spoke)
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke-app"
  resource_group_name       = azurerm_resource_group.rg_hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_app.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-app-to-hub"
  resource_group_name       = azurerm_resource_group.rg_spoke_app.name
  virtual_network_name      = azurerm_virtual_network.spoke_app.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# ------------------------------------------------------------------------------
# 4. Route Table (UDR) - Forced Egress to Azure Firewall
# ------------------------------------------------------------------------------
resource "azurerm_route_table" "spoke_udr" {
  name                          = "${var.enterprise_prefix}-rt-spoke-app-${var.environment}"
  resource_group_name           = azurerm_resource_group.rg_spoke_app.name
  location                      = azurerm_resource_group.rg_spoke_app.location
  disable_bgp_route_propagation = false

  route {
    name                   = "route-to-firewall-default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.afw.ip_configuration[0].private_ip_address
  }

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "app_tier_udr" {
  subnet_id      = azurerm_subnet.app_tier.id
  route_table_id = azurerm_route_table.spoke_udr.id
}

# ------------------------------------------------------------------------------
# 5. Network Security Group (NSG) - Zero-Trust Default Deny
# ------------------------------------------------------------------------------
resource "azurerm_network_security_group" "nsg_app" {
  name                = "${var.enterprise_prefix}-nsg-app-${var.environment}"
  resource_group_name = azurerm_resource_group.rg_spoke_app.name
  location            = azurerm_resource_group.rg_spoke_app.location

  security_rule {
    name                       = "Allow-Inbound-HTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.hub_vnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_tier.id
  network_security_group_id = azurerm_network_security_group.nsg_app.id
}