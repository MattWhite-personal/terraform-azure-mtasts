resource "azurerm_dns_cname_record" "mta-sts" {
  name                = "mta-sts"
  zone_name           = var.domain-name
  resource_group_name = var.dns-resource-group
  ttl                 = 300
  target_resource_id  = azurerm_cdn_endpoint.mtastsendpoint.id
  tags                = var.tags
}

resource "azurerm_dns_cname_record" "cdnverify" {
  name                = "cdnverify.${azurerm_dns_cname_record.mta-sts.name}"
  zone_name           = var.domain-name
  resource_group_name = var.dns-resource-group
  ttl                 = 300
  record              = "cdnverify.${azurerm_cdn_endpoint.mtastsendpoint.name}.azureedge.net"
  tags                = var.tags
}

resource "azurerm_dns_txt_record" "mta-sts" {
  name                = "_mta-sts"
  zone_name           = var.domain-name
  resource_group_name = var.dns-resource-group
  ttl                 = 300
  tags                = var.tags

  record {
    value = "v=STSv1; id=${local.policyhash}"
  }
}

resource "azurerm_dns_txt_record" "smtp-tls" {
  name                = "_smtp._tls"
  zone_name           = var.domain-name
  resource_group_name = var.dns-resource-group
  ttl                 = 300
  tags                = var.tags

  record {
    value = "v=TLSRPTv1; rua=mailto:${local.tls_rpt_email}"
  }
}
