data "azurerm_client_config" "current" {}

module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "westeurope"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "storage" {
  source  = "codectl/sa/azure"
  version = "~> 1.0"

  storage = {
    name                = module.naming.storage_account.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name

    blob_properties = {
      containers = {
        sales = {
          access_type = "private"
        }
      }
    }
  }
}

module "ds" {
  source  = "codectl/ds/azure"
  version = "~> 1.0"

  location            = module.rg.groups.demo.location
  resource_group_name = module.rg.groups.demo.name

  account = {
    name = module.naming.data_share_account.name_unique

    role_assignments = {
      storage_reader = {
        scope                = module.storage.account.id
        role_definition_name = "Storage Blob Data Reader"
      }
    }

    shares = {
      sales = {
        kind        = "CopyBased"
        description = "monthly sales export"

        datasets = {
          blob_storage = {
            sales_container = {
              container_name = module.storage.containers["sales"].name
              folder_path    = "exports"

              storage_account = {
                name                = module.storage.account.name
                resource_group_name = module.storage.account.resource_group_name
                subscription_id     = data.azurerm_client_config.current.subscription_id
              }
            }
          }
        }
      }
    }
  }
}
