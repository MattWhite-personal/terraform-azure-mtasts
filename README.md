# MTA-STS/TLS-RPT Azure code

## Repo to be updated and overhauled with new release

This repo is inspired by the UK NCSC [terraform-aws-mtasts](https://github.com/ukncsc/terraform-aws-mtasts) module to deploy [MTS-STS](https://tools.ietf.org/html/rfc8461) and [TLS-RPT](https://tools.ietf.org/html/rfc8460) policy for a domin in Microsoft Azure using [Terraform](https://www.terraform.io/).

The module requires the following core configuration to be in place already:
* existing Azure Resource Group that will be used to deploy the configuration
* DNS zone for the domain in scope to reside in the same resource group

The module then deploys the following additional resources:
* Storage account to host the mta-sts policy file
* Static website linked to the storage account
* CDN Profile and endpoint to support hosting the custom mta-sts.domain.com record
* DNS CNAME records in the existing dns zone for the CDN endpoint
* DNS TXT records to setup TLS-RPT and MTA-STS policy entries

## Limitations of current code

As discussed on the [azurerm_cdn_endpoint_custom_domain](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_endpoint_custom_domain) docs pages it is not possible to enable HTTPs using Terraform and this just needs to be enabled once after initial deployment.

To get around this a single Azure CLI command can be run to enable the HTTPS endpoint on the custom domain, substitute the resouregroup name


## How to use this Module

This module assumes that all the following required resources already exist within an accessible Azure subscription. Use the code block below to add to your existing Terraform configuration to deploy the code and repeat for each domain in scope

```terraform
module "mtastspolicy_tftest" {
  source          = "github.com/MattWhite-personal/terraform-azure-mtasts/terraform"
  resource_group  = "resource-group-name"
  DOMAIN          = "domainname.co.uk"
  MTASTSMODE      = "testing"
  MX              = ["mx1.domain.com","mx2.domain.com"]
  REPORTING_EMAIL = "tls-rpt"
}

```

After the initial deployment you can enable the HTTPs custom domain on the CDN Endpoint using the following Azure CLI command, substituting the relevant variables
````
az cdn custom-domain enable-https -g <<resource_group>> --profile-name cdnmtasts --endpoint-name mtasts-endpoint -n cdncd-mtastsendpoint --min-tls-version 1.2
````

# Issues that need further work
<!-- issueTable -->

| Title                                                                                                                                          |         Status          |                                                             Assignee                                                              | Body                                                                                                                                                                                                                                                                                      |
| :--------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------: | :-------------------------------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a href="https://github.com/MattWhite-personal/terraform-azure-mtasts/issues/10">Review dependency on cname record when removing resources</a> | :eight_spoked_asterisk: |                                                                                                                                   | Code deploys without issue however when a module is removed the destroy fails because the mta-sts cname record linked to the cdn endpoint still exists.<br /><br />Workaround - manually delete the mta-sts cname record and then re-run terraform apply and the resources are cleaned up |
| <a href="https://github.com/MattWhite-personal/terraform-azure-mtasts/issues/7">Integrate support for https</a>                                | :eight_spoked_asterisk: | <a href="https://github.com/MattWhite-personal"><img src="https://avatars.githubusercontent.com/u/74813866?v=4" width="20" /></a> | - [ ] review the logic for the azurerm terraform provider to complete this natively<br />- [ ] add capability for the output of the module to share code for the end user to run it manually                                                                                              |

<!-- issueTable -->
