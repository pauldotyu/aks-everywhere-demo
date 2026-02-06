data "azuread_application_published_app_ids" "well_known" {}
data "azuread_client_config" "current" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  msgraph_oauth2_permission_scope_ids = {
    for scope in data.azuread_service_principal.msgraph.oauth2_permission_scopes :
    scope.value => scope.id
  }
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "azurerm_resource_group" "example" {
  name     = "rg-everywhere${random_integer.example.result}"
  location = var.location
}

resource "azurerm_user_assigned_identity" "example" {
  name                = "mi-everywhere${random_integer.example.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azuread_application" "example" {
  display_name            = "app-everywhere-${random_integer.example.result}"
  owners                  = [data.azuread_client_config.current.object_id]
  sign_in_audience        = "AzureADMyOrg"
  group_membership_claims = ["ApplicationGroup"]

  web {
    redirect_uris = [
      "https://localhost:9000/auth/callback"
    ]
  }

  public_client {
    redirect_uris = [
      "http://localhost:8085/auth/callback"
    ]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["profile"]
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["email"]
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }
  }

  optional_claims {
    id_token {
      name      = "groups"
      essential = true
    }
  }
}

resource "azuread_service_principal" "example" {
  client_id = azuread_application.example.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "example" {
  service_principal_object_id          = azuread_service_principal.example.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email", "User.Read"]
}

data "azuread_group" "example" {
  display_name = var.admin_group_name
}

resource "azuread_app_role_assignment" "example" {
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default app role
  principal_object_id = data.azuread_group.example.object_id
  resource_object_id  = azuread_service_principal.example.object_id
}

resource "azapi_resource" "fleet" {
  type      = "Microsoft.ContainerService/fleets@2025-08-01-preview"
  name      = "fl-everywhere${random_integer.example.result}"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      hubProfile = {
        agentProfile = {}
        apiServerAccessProfile = {
          enablePrivateCluster  = false
          enableVnetIntegration = false
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "fleet" {
  scope                = azapi_resource.fleet.id
  role_definition_name = "Azure Kubernetes Fleet Manager RBAC Cluster Admin"
  principal_id         = data.azuread_client_config.current.object_id
}

resource "azurerm_monitor_workspace" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "prom-everywhere${random_integer.example.result}"
}

resource "azurerm_log_analytics_workspace" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "log-everywhere${random_integer.example.result}"
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# data "cloudinit_config" "example" {
#   base64_encode = true
#   gzip          = true

#   part {
#     filename     = "cloud-config.yaml"
#     content_type = "text/cloud-config"

#     content = file("${path.module}/cloud-config.yaml")
#   }

#   part {
#     filename     = "install.sh"
#     content_type = "text/x-shellscript"

#     content = templatefile("${path.module}/install.sh", {
#       current_user = var.vm_username
#     })
#   }
# }

# data "http" "current_ip" {
#   url = "https://api.ipify.org"
# }

# resource "tls_private_key" "example" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "local_file" "ssh_private_key" {
#   filename        = "${path.module}/ssh_private_key"
#   content         = tls_private_key.example.private_key_pem
#   file_permission = "0600"
# }

# resource "azurerm_ssh_public_key" "example" {
#   name                = "ssh-everywhere${random_integer.example.result}"
#   resource_group_name = azurerm_resource_group.example.name
#   location            = azurerm_resource_group.example.location
#   public_key          = tls_private_key.example.public_key_openssh
# }

# resource "azurerm_virtual_network" "example" {
#   name                = "vnet-everywhere${random_integer.example.result}"
#   address_space       = ["10.0.0.0/16"]
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
# }

# resource "azurerm_subnet" "example" {
#   name                 = "internal"
#   resource_group_name  = azurerm_resource_group.example.name
#   virtual_network_name = azurerm_virtual_network.example.name
#   address_prefixes     = ["10.0.2.0/24"]
# }

# resource "azurerm_network_security_group" "example" {
#   name                = "nsg-everywhere${random_integer.example.result}"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name

#   security_rule {
#     name                       = "SSH"
#     priority                   = 300
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "${data.http.current_ip.response_body}/32"
#     destination_address_prefix = "*"
#   }
# }

# resource "azurerm_subnet_network_security_group_association" "example" {
#   subnet_id                 = azurerm_subnet.example.id
#   network_security_group_id = azurerm_network_security_group.example.id
# }

# resource "azurerm_public_ip" "example" {
#   for_each            = { for vm in var.virtual_machines : vm.name => vm }
#   name                = "pip-${each.value.name}"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# resource "azurerm_network_interface" "example" {
#   for_each            = { for vm in var.virtual_machines : vm.name => vm }
#   name                = "nic-${each.value.name}"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.example.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.example[each.key].id
#   }
# }

# resource "azurerm_linux_virtual_machine" "example" {
#   for_each                        = { for vm in var.virtual_machines : vm.name => vm }
#   name                            = each.value.name
#   resource_group_name             = azurerm_resource_group.example.name
#   location                        = azurerm_resource_group.example.location
#   size                            = each.value.size
#   admin_username                  = var.vm_username
#   disable_password_authentication = true

#   network_interface_ids = [
#     azurerm_network_interface.example[each.key].id,
#   ]

#   admin_ssh_key {
#     username   = var.vm_username
#     public_key = tls_private_key.example.public_key_openssh
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Premium_LRS"
#     disk_size_gb         = 1000
#   }

#   source_image_reference {
#     publisher = "canonical"
#     offer     = "ubuntu-24_04-lts"
#     sku       = "server"
#     version   = "latest"
#   }

#   custom_data = data.cloudinit_config.example.rendered
# }