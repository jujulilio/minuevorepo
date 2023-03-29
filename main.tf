//terraform

provider "azurerm" {
  features {}
}
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-activity-centralus"
  location = "east us"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet1-network"
  address_space       = ["172.16.1.0/24"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_subnet" "subnetvm" {
  name                 = "vmsubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.1.128/25"]
  service_endpoints    = ["Microsoft.Sql"]
}

resource "azurerm_network_interface" "incfa" {
  name                = "infa-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "int"
    subnet_id                     = azurerm_subnet.subnetvm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm001" {
  name                = "vm-machine-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "user1$"
  admin_password      = "Reynelalberto89"
  network_interface_ids = [azurerm_network_interface.incfa.id,]
  availability_set_id   = azurerm_availability_set.avail.id


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  }


resource "azurerm_availability_set" "avail" {
  name                = "avail-set"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  managed             = true
  platform_update_domain_count = 2
  platform_fault_domain_count = 2

}
resource "azurerm_subnet" "bastionsubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.1.0/25"]
}

resource "azurerm_public_ip" "ipbas" {
  name                = "bastionip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastionaz" {
  name                = "AzureBastionSubnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "confbastion"
    subnet_id            = azurerm_subnet.bastionsubnet.id
    public_ip_address_id = azurerm_public_ip.ipbas.id
  }
}
resource "azurerm_storage_account" "storage" {
  name                     = "stactivity000001"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_blob" "stactivity-archivo" {
  name                   = "stfst-archivo.txt"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.stcontainer.name
  type                   = "Block"
  source_content         = "Hola, mundo!"
}

resource "azurerm_storage_container" "stcontainer" {
  name                  = "stcon-container"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_mssql_server" "sqls01" {
  name                         = "sql-sqlserver"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "4dm1n157r470r"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"
}

resource "azurerm_mssql_database" "sqldb" {
  name           = "acitivity-sqldb-1"
  server_id      = azurerm_mssql_server.sqls01.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 4
  sku_name       = "S0"
  zone_redundant = false

  tags = {
    foo = "bar"
  }
}
resource "azurerm_mssql_virtual_network_rule" "mvnru" {
  name      = "sql-vnet-rule"
  server_id = azurerm_mssql_server.sqls01.id
  subnet_id = azurerm_subnet.subnetvm.id
}
 
resource "azurerm_key_vault" "kv-01" {
  name                       = "key-01-centralus"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }
}

resource "azurerm_key_vault_secret" "kvsec-01" {
  name         = "user"
  value        = "user1$"
  key_vault_id = azurerm_key_vault.kv-01.id
}
resource "azurerm_key_vault_secret" "kvsec-02" {
  name         = "password"
  value        = "Reynelalberto89"
  key_vault_id = azurerm_key_vault.kv-01.id
}