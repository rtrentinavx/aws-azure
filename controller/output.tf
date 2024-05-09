output "controller_public_ip" {
  value = module.aviatrix_controller_azure.avx_controller_public_ip
}
output "controller_private_ip" {
  value = module.aviatrix_controller_azure.avx_controller_private_ip
}
output "copilot_public_ip" {
  value = module.copilot_build_azure.public_ip
}
output "copilot_private_ip" {
  value = module.copilot_build_azure.private_ip
}