data "azurerm_network_service_tags" "AzureFrontDoor-BackEnd" {
  location = var.location
  service  = "AzureFrontDoor.Backend"

}

data "azurerm_resource_group" "afd" {
  count = var.use-existing-front-door ? 0 : 1
  name  = var.afd-resource-group
}
