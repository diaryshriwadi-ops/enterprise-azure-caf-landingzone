terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47.0"
    }
  }

  # Production Remote State Backend with Lease Locking
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state-prod"
  #   storage_account_name = "sttfstateenterpriseprod"
  #   container_name       = "tfstate"
  #   key                  = "enterprise.caf.landingzone.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}