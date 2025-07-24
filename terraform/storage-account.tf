resource "azurerm_storage_account" "mta-sts" {
  #checkov:skip=CKV_AZURE_35:The storage account can be publicly accessed
  #checkov:skip=CKV_AZURE_59:The storage account can be publicly accessed
  #checkov:skip=CKV_AZURE_206:Storage replication is not requrired
  #checkov:skip=CKV_AZURE_33:Not using queue service
  #checkov:skip=CKV_AZURE_43:Own naming convention is in use
  #checkov:skip=CKV2_AZURE_1:Customer Managed Key is not required
  #checkov:skip=CKV2_AZURE_33:Private endpoints not suitable for storage account
  #checkov:skip=CKV2_AZURE_40:Dont care about this
  name                            = "st${local.storage_prefix}mtasts"
  resource_group_name             = var.stg-resource-group
  location                        = var.location
  account_replication_type        = "LRS"
  account_tier                    = "Standard"
  min_tls_version                 = "TLS1_2"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
  local_user_enabled              = false
  shared_access_key_enabled       = true
  tags                            = var.tags

  network_rules {
    default_action = "Allow"
    #bypass         = ["AzureServices"]
    #ip_rules       = var.permitted-ips
  }
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
  sas_policy {
    expiration_period = "01.12:00:00"
  }
}

resource "azurerm_storage_account_static_website" "mta-sts" {
  storage_account_id = azurerm_storage_account.mta-sts.id
  error_404_document = azurerm_storage_blob.error.name
  index_document     = azurerm_storage_blob.index.name
}

resource "azurerm_storage_blob" "mta-sts" {
  name                   = ".well-known/mta-sts.txt"
  storage_account_name   = azurerm_storage_account.stmtasts.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = <<EOF
version: STSv1
mode: ${var.mtastsmode}
${join("", formatlist("mx: %s\n", var.mx-records))}max_age: ${var.max-age}
  EOF
}

resource "azurerm_storage_blob" "index" {
  name                   = "index.htm"
  storage_account_name   = azurerm_storage_account.mta-sts.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = "<html><head><title>Nothing to see</title></head><body><center><h1>Nothing to see</h1></center></body></html>"
}

resource "azurerm_storage_blob" "error" {
  name                   = "error.htm"
  storage_account_name   = azurerm_storage_account.mta-sts.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = "<html><head><title>Error Page</title></head><body><center><h1>Nothing to see</h1></center></body></html>"
}