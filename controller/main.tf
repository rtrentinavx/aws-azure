resource "null_resource" "accept_license_copilot" {
  provisioner "local-exec" {
    command = "python3 ${path.module}/accept_license.py"
  }
}
module "aviatrix_controller_azure" {
  source                          = "AviatrixSystems/azure-controller/aviatrix"
  controller_name                 = var.controller_name
  incoming_ssl_cidr               = var.incoming_ssl_cidr
  avx_controller_admin_email      = var.avx_controller_admin_email
  avx_controller_admin_password   = var.avx_controller_admin_password
  account_email                   = var.account_email
  access_account_name             = var.access_account_name
  aviatrix_customer_id            = var.aviatrix_customer_id
  controller_virtual_machine_size = var.controller_virtual_machine_size
  location                        = var.location
  resource_group_name             = var.resource_group_name
  vnet_name                       = var.vnet_name
  subnet_name                     = var.subnet_name
  subnet_id                       = data.azurerm_subnet.subnet.id
}
module "copilot_build_azure" {
  source                         = "github.com/AviatrixSystems/terraform-modules-copilot.git//copilot_build_azure"
  virtual_machine_admin_password = var.virtual_machine_admin_password
  copilot_name                   = var.copilot_name
  location                       = var.location
  allowed_cidrs = {
    "tcp_cidrs" = {
      priority = "100"
      protocol = "Tcp"
      ports    = ["443"]
      cidrs    = var.incoming_ssl_cidr
    }
    "udp_cidrs" = {
      priority = "200"
      protocol = "Udp"
      ports    = ["5000", "31283"]
      cidrs    = var.incoming_ssl_cidr
    }
  }
  use_existing_vnet              = true
  resource_group_name            = var.resource_group_name
  subnet_id                      = data.azurerm_subnet.subnet.id
  virtual_machine_size           = var.copilot_virtual_machine_size
  default_data_disk_size         = var.default_data_disk_size
  controller_public_ip           = module.aviatrix_controller_azure.avx_controller_public_ip
  controller_private_ip          = module.aviatrix_controller_azure.avx_controller_private_ip
  virtual_machine_admin_username = var.virtual_machine_admin_username
}
