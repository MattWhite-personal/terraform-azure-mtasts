# MTA-STS/TLS-RPT Azure Terraform Module

This Terraform module, inspired by the UK NCSC [terraform-aws-mtasts](https://github.com/ukncsc/terraform-aws-mtasts) project, deploys [MTA-STS](https://tools.ietf.org/html/rfc8461) and [TLS-RPT](https://tools.ietf.org/html/rfc8460) email security policies to Microsoft Azure using Terraform.

## Overview

The module automates deployment of MTA-STS and TLS-RPT infrastructure in Azure, enabling organizations to implement email security policies that protect against man-in-the-middle attacks and track TLS failures for email delivery.

## Prerequisites

The following Azure resources must exist in your subscription before using this module:

- **Azure Resource Groups**: Separate resource groups for DNS, storage account, and Azure Front Door resources
- **DNS Zone**: An existing Azure DNS Zone for your domain, hosted in the DNS resource group

## Resources Deployed

The module creates the following Azure resources:

- **Storage Account**: Hosts the MTA-STS policy file with static website enabled
  - GRS replication for redundancy
  - TLS 1.2 minimum version enforcement
  - Network security rules with IP restrictions via `permitted-ips` variable
  - 7-day retention policies for blob deletion protection

- **Azure Front Door (CDN)**: Provides global distribution and custom domain hosting
  - Currently only Standard SKU is supported by the module
  - Option to use existing Front Door instance or create new one
  - Custom domain with managed certificate support
  - HTTPS-only routing with automatic HTTP→HTTPS redirection

- **DNS Records**: 
  - CNAME record for `mta-sts.yourdomain.com` pointing to Front Door endpoint
  - TXT record `_mta-sts.yourdomain.com` with MTA-STS policy ID
  - TXT record `_smtp._tls.yourdomain.com` with TLS-RPT reporting endpoint
  - DNS validation record for Front Door custom domain certificate

- **MTA-STS Policy File**: Automatically generated `.well-known/mta-sts.txt` hosted on the storage account
  - Configurable mode: `testing` or `enforced`
  - Includes specified MX records
  - Configurable cache lifetime (`max-age`)

## How to Use This Module

Add the module to your Terraform configuration using the following example:

### Basic Usage

```terraform
module "mta-sts-domain" {
  source = "github.com/MattWhite-personal/terraform-azure-mtasts/terraform"

  # Required variables
  domain-name       = "yourdomain.com"
  dns-resource-group = azurerm_resource_group.dns.name
  afd-resource-group = azurerm_resource_group.frontdoor.name
  stg-resource-group = azurerm_resource_group.storage.name
  mx-records         = ["mail.yourdomain.com", "mail2.yourdomain.com"]

  # Optional variables with sensible defaults
  location           = "uksouth"
  mtastsmode         = "testing"        # Change to "enforced" in production
  max-age            = 86400            # 1 day in seconds
  reporting-email    = "tls-rpt@yourdomain.com"
  resource-prefix    = "mta"
  permitted-ips      = ["203.0.113.0/24"] # Restrict storage access to specific IPs

  # Azure tags for resource management
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

### Using an Existing Front Door

If you already have an Azure Front Door instance and want to reuse it:

```terraform
module "mta-sts-domain" {
  source = "github.com/MattWhite-personal/terraform-azure-mtasts/terraform"

  # Required variables
  domain-name           = "yourdomain.com"
  dns-resource-group    = azurerm_resource_group.dns.name
  afd-resource-group    = azurerm_resource_group.frontdoor.name
  stg-resource-group    = azurerm_resource_group.storage.name
  mx-records            = ["mail.yourdomain.com"]

  # Use existing Front Door
  use-existing-front-door = true
  existing-front-door     = data.azurerm_cdn_frontdoor_profile.existing.id

  reporting-email = "tls-rpt@yourdomain.com"
  resource-prefix = "mta"

  tags = local.tags
}
```

### Multi-Domain Configuration

```terraform
locals {
  domains = {
    "example.com" = ["mail.example.com", "mail2.example.com"]
    "test.org"    = ["mail.test.org"]
  }
}

module "mta-sts" {
  for_each = local.domains

  source = "github.com/MattWhite-personal/terraform-azure-mtasts/terraform"

  domain-name       = each.key
  mx-records         = each.value
  dns-resource-group = azurerm_resource_group.dns.name
  afd-resource-group = azurerm_resource_group.frontdoor.name
  stg-resource-group = azurerm_resource_group.storage.name
  resource-prefix    = "mta${index(keys(local.domains), each.key)}"
  reporting-email    = "tls-rpt@${each.key}"

  tags = local.tags
}
```

### Variable Reference

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `domain-name` | string | Yes | - | The domain name for which to deploy MTA-STS/TLS-RPT |
| `mx-records` | list(string) | Yes | - | List of MX records to include in the MTA-STS policy |
| `dns-resource-group` | string | Yes | - | Resource group containing the DNS Zone |
| `afd-resource-group` | string | Yes | - | Resource group for Azure Front Door resources |
| `stg-resource-group` | string | Yes | - | Resource group for the storage account |
| `location` | string | No | `uksouth` | Azure region for resource deployment |
| `mtastsmode` | string | No | `testing` | MTA-STS policy mode: `testing` or `enforced` |
| `max-age` | number | No | `86400` | MTA-STS cache lifetime in seconds (1 day) |
| `reporting-email` | string | No | `tls-rpt` | Email address for TLS-RPT reports; auto-appended with domain if no `@` |
| `resource-prefix` | string | Yes | - | Prefix for generated resource names |
| `afd-version` | string | No | `standard` | Azure Front Door SKU: `standard` or `premium` |
| `use-existing-front-door` | bool | No | `false` | Set `true` to use existing Front Door instance |
| `existing-front-door` | string | No | `` | Front Door resource ID when `use-existing-front-door = true` |
| `permitted-ips` | list(string) | No | `[]` | IP addresses/CIDR ranges allowed to access storage account |
| `tags` | map(string) | No | `{}` | Azure tags applied to all resources |

## Post-Deployment Configuration

HTTPS on the custom domain is managed by Azure Front Door using automatic managed certificates. The module creates all necessary DNS validation records automatically.

If you need to manually manage HTTPS settings, the custom domain created will be named using the pattern `cdn{resource-prefix}mtasts`.

## Known Limitations

### Resource Removal

There is a known issue when destroying the module: if DNS records tied to the Front Door custom domain exist, Terraform may fail to destroy the custom domain. 

**Workaround**: Manually delete the `mta-sts` CNAME record from your DNS Zone before running `terraform destroy`, then proceed with the destroy operation.

### Azure Front Door Premium Support

The code in the module needs to be extended to support Azure Front Door Premium, Private Link and Managed Security Rule sets.

## Additional References

- [MTA-STS RFC 8461](https://tools.ietf.org/html/rfc8461)
- [TLS-RPT RFC 8460](https://tools.ietf.org/html/rfc8460)
- [Azure Front Door Documentation](https://docs.microsoft.com/en-us/azure/frontdoor/)
