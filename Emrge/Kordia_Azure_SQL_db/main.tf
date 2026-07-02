terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.79.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "PowerBI" {
  name     = "PowerBI"
  location = "Australia East "
#  tags = {
#    envionment = "Prod"
#  }
}

resource "azurerm_mssql_server" "etppowerbisql" {
  name                         = "etppowerbisql"
  resource_group_name          = azurerm_resource_group.PowerBI.name
  location                     = azurerm_resource_group.PowerBI.location
  version                      = "12.0"
  administrator_login          = "etp"
  administrator_login_password = "+A@fYPFt8mh%G*W>JhfZm,pJ#e=^q,}364v7YnHE"
}

resource "azurerm_mssql_database" "emrge_data" {
  name         = "emrge_data"
  server_id    = azurerm_mssql_server.etppowerbisql.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  tags = {
    foo = "bar"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}