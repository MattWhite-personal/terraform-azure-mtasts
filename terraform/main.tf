
resource "azurerm_resource_group" "rg" {
  name     = "rg-mtasts"
  location = var.location
}

resource "azurerm_dns_zone" "dns-zone" {
  name                = "${var.DOMAIN}"
  resource_group_name = azurerm_resource_group.rg.name
}

locals {
  tls_rpt_email = length(split("@", var.REPORTING_EMAIL)) == 2 ? var.REPORTING_EMAIL : "${var.REPORTING_EMAIL}@${var.DOMAIN}"
  policyhash   = formatdate("YYYYMMDDhhmmss",timestamp())
  mx_records   = split(",", var.MX)
}

resource "azurerm_storage_account" "stmtasts" {
    name                        = "stmtasts"
    resource_group_name         = azurerm_resource_group.rg.name
    location                    = var.location
    account_replication_type    = "LRS"
    account_tier                = "Standard"
    min_tls_version             = "TLS1_2"
    account_kind                = "StorageV2"
    static_website {
      index_document = "index.htm"
      error_404_document = "error.htm"
    }
}

resource "azurerm_storage_blob" "mta-sts" {
  name                   = ".well-known/mta-sts.txt"
  storage_account_name   = azurerm_storage_account.stmtasts.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = <<EOF
version: STSv1
mode: ${var.MTASTSMODE}
${join("", formatlist("mx: %s\n", local.mx_records))}max_age: ${var.MAX_AGE}
  EOF
}

resource "azurerm_storage_blob" "index" {
  name                   = "index.htm"
  storage_account_name   = azurerm_storage_account.stmtasts.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = "<html><head><title>Nothing to see</title></head><body><center><h1>Nothing to see</h1></center></body></html>"
}

resource "azurerm_storage_blob" "error" {
  name                   = "error.htm"
  storage_account_name   = azurerm_storage_account.stmtasts.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = "<html><head><title>Error Page</title></head><body><center><h1>Nothing to see</h1></center></body></html>"
}

resource "azurerm_cdn_profile" "cdnmtasts" {
  name                = "cdnmtasts"
  location            = "global"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "mtastsendpoint" {
  name                = "mtasts-endpoint"
  profile_name        = azurerm_cdn_profile.cdnmtasts.name
  location            = "global"
  resource_group_name = azurerm_resource_group.rg.name

  origin {
    name      = "mtasts-endpoint"
    host_name = azurerm_storage_account.stmtasts.primary_web_host
  }

  origin_host_header = azurerm_storage_account.stmtasts.primary_web_host

  delivery_rule {
    name  = "EnforceHTTPS"
    order = "1"

    request_scheme_condition {
      operator     = "Equal"
      match_values = ["HTTP"]
    }

    url_redirect_action {
      redirect_type = "Found"
      protocol      = "Https"
    }
  }
}

resource "azurerm_dns_cname_record" "mta-sts-cname" {
  name                = "mta-sts"
  zone_name           = azurerm_dns_zone.test-mjw-co-uk.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  target_resource_id = azurerm_cdn_endpoint.mtastsendpoint.id
  depends_on          = [azurerm_cdn_endpoint.mtastsendpoint]
}

resource "azurerm_dns_cname_record" "cdnverify-mta-sts" {
  name                = "cdnverity.${azurerm_dns_cname_record.mta-sts-cname.name}"
  zone_name           = azurerm_dns_zone.test-mjw-co-uk.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = "cdnverify.${azurerm_cdn_endpoint.mtastsendpoint.name}.azureedge.net"
}

resource "azurerm_dns_txt_record" "mta-sts" {
  name                = "_mta-sts"
  zone_name           = azurerm_dns_zone.test-mjw-co-uk.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  record {
    value = "v=STSv1; id=${local.policyhash}"
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "mtastscustomdomain" {
  name            = "cdncd-mtastsendpoint"
  cdn_endpoint_id = azurerm_cdn_endpoint.mtastsendpoint.id
  host_name       = "${azurerm_dns_cname_record.mta-sts-cname.name}.${azurerm_dns_zone.test-mjw-co-uk.name}"
}

resource "azurerm_dns_txt_record" "smtp-tls" {
  name                = "_smtp._tls"
  zone_name           = azurerm_dns_zone.test-mjw-co-uk.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  record {
    value = "v=TLSRPTv1; rua=${local.tls_rpt_email}"
  }
}