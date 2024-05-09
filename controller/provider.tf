terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.102.0"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
  backend "azurerm" {
    resource_group_name  = "avx-mgmt-rg"
    storage_account_name = "labtestazuretstg"
    container_name       = "tfstate"
    key                  = "controller.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}