output "hub_vnet_id" {
  description = "The Resource ID of the Central Hub Virtual Network"
  value       = azurerm_virtual_network.hub.id
}

output "azure_firewall_private_ip" {
  description = "Private IP address of Azure Firewall for UDR routing"
  value       = azurerm_firewall.afw.ip_configuration[0].private_ip_address
}

output "azure_firewall_public_ip" {
  description = "Public IP address of Azure Firewall for internet egress"
  value       = azurerm_public_ip.firewall_pip.ip_address
}

output "app_spoke_vnet_id" {
  description = "The Resource ID of the Application Spoke Virtual Network"
  value       = azurerm_virtual_network.spoke_app.id
}

output "app_tier_subnet_id" {
  description = "The Subnet ID of the Application Tier"
  value       = azurerm_subnet.app_tier.id
}