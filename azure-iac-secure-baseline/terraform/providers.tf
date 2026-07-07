terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # Lab 02 will move state to an Azure Storage backend. For now it's local:
  # backend "local" {}
}

provider "azurerm" {
  features {
    key_vault {
      # allow terraform destroy to fully purge the vault in the lab
      purge_soft_delete_on_destroy = true
    }
  }
}
