# ================================
# Resource Group
# ================================
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# ================================
# Network Security Group
# ================================
resource "azurerm_network_security_group" "app_nsg" {
  name                = "Appnsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    source_port_range          = "*"
  }

  security_rule {
    name                       = "Allow-Java"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    source_port_range          = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    source_port_range          = "*"
  }
}

# ================================
# Public IP
# ================================
resource "azurerm_public_ip" "public_ip" {
  name                = "MyAppVM-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# ================================
# NIC
# ================================
resource "azurerm_network_interface" "nic" {
  name                = "app-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# ================================
# NSG Association
# ================================
resource "azurerm_network_interface_security_group_association" "assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

# ================================
# PostgreSQL Server
# ================================
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "kiranpostgres5454"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location

  administrator_login    = var.postgres_admin
  administrator_password = var.postgres_password

  sku_name   = "B_Standard_B1ms"
  version    = "14"

  storage_mb = 32768

  zone = "1"

  backup_retention_days = 7

  public_network_access_enabled = true
}

# ================================
# PostgreSQL Database
# ================================
resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "studentdb"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ================================
# PostgreSQL Firewall Rule
# ================================
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_vm" {
  name      = "Allow-VM-IP"
  server_id = azurerm_postgresql_flexible_server.postgres.id

  start_ip_address = azurerm_public_ip.public_ip.ip_address
  end_ip_address   = azurerm_public_ip.public_ip.ip_address

  depends_on = [
    azurerm_public_ip.public_ip,
    azurerm_postgresql_flexible_server.postgres
  ]
}

# ================================
# Virtual Machine
# ================================
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "MyAppVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_D2s_v3"

  admin_username = var.admin_username
  admin_password = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/setup.sh", {
    DB_HOST     = azurerm_postgresql_flexible_server.postgres.fqdn
    DB_USER     = var.postgres_admin
    DB_PASSWORD = var.postgres_password
    DB_NAME     = azurerm_postgresql_flexible_server_database.db.name
  }))
}


