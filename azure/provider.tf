terraform {
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "3.1.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.102.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "avx-mgmt-rg"  
    storage_account_name = "labtestazuretstg"                      
    container_name       = "tfstate"                      
    key                  = "east.terraform.tfstate"       
  }
}
provider "aviatrix" {
  controller_ip = var.controller_ip
  username      = var.username
  password      = var.password
}
provider "azurerm" {
  features {}
}

