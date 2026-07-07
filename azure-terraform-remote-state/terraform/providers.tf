terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state in Azure Storage. Left empty on purpose — the values are
  # supplied at init time via -backend-config flags (see the lab guide, Part A).
  # The azurerm backend uses a blob lease for automatic state LOCKING.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
