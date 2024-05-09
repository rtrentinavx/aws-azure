terraform {
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "3.1.4"
    }
  }
  backend "s3" {
    bucket = "lab-avx-terraform-state"
    key    = "b.aws.transit.state.file"
    region = "us-east-1"
  }
}
provider "aws" {
  region = var.region
}

provider "aviatrix" {
  controller_ip = var.controller_ip
  username      = var.username
  password      = var.password
}

# $ export AVIATRIX_USERNAME="admin"
# $ export AVIATRIX_PASSWORD="password"
