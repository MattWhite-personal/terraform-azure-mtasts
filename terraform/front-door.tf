resource "azurerm_cdn_frontdoor_profile" "mta-sts" {
  count               = var.use-existing-front-door ? 0 : 1
  name                = "afd-mta-sts"
  resource_group_name = data.azurerm_resource_group.example.name
  sku_name            = lookup(local.afd-version, var.afd-version, local.afd-version["default"])

  tags = var.tags
}



