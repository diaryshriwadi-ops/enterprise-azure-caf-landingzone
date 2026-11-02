variable "environment" {
  type        = string
  description = "Target environment tier (dev, uat, prod)"
  default     = "prod"

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, uat, prod."
  }
}

variable "primary_location" {
  type        = string
  description = "Primary Azure region for Landing Zone deployment"
  default     = "eastus2"
}

variable "enterprise_prefix" {
  type        = string
  description = "Organization naming convention prefix"
  default     = "shriwadi"
}

variable "hub_vnet_cidr" {
  type        = string
  description = "CIDR block for Central Hub VNet"
  default     = "10.0.0.0/16"
}

variable "firewall_subnet_cidr" {
  type        = string
  description = "Dedicated subnet CIDR for Azure Firewall (minimum /26 required)"
  default     = "10.0.1.0/24"
}

variable "gateway_subnet_cidr" {
  type        = string
  description = "Dedicated subnet CIDR for VPN/ExpressRoute Gateway"
  default     = "10.0.255.0/27"
}

variable "app_spoke_vnet_cidr" {
  type        = string
  description = "CIDR block for Application Workload Spoke VNet"
  default     = "10.1.0.0/16"
}

variable "tags" {
  type        = map(string)
  description = "Enterprise governance tags enforced across all resources"
  default = {
    Architecture  = "Microsoft-CAF"
    ManagedBy     = "Terraform"
    SecurityTier  = "Enterprise-Zero-Trust"
    CostCenter    = "Platform-Core"
    Owner         = "Ramneek-Shriwadi"
  }
}