# TKG cluster

provider "azurerm" {
  features {}


  subscription_id = var.subscription_id

}

resource "azurerm_resource_group" "tkg_resource_group" {
  name     = "${var.resource_group}"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "tap-network"
  address_space       = ["10.30.0.0/16"]
  location            = azurerm_resource_group.tkg_resource_group.location
  resource_group_name = azurerm_resource_group.tkg_resource_group.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.tkg_resource_group.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.30.2.0/24"]
}


# -------------------------------------- START BOOTSTRAP BOX ---------------------------------------------

resource "azurerm_public_ip" "bootstrap_pip" {
  name                = "bootstrap-pip"
  resource_group_name = azurerm_resource_group.tkg_resource_group.name
  location            = azurerm_resource_group.tkg_resource_group.location
  allocation_method   = "Static"
  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_interface" "bootstrap_nic" {  
  name                = "bootstrap-nic"
  resource_group_name = azurerm_resource_group.tkg_resource_group.name
  location            = azurerm_resource_group.tkg_resource_group.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bootstrap_pip.id
  }

}

resource "azurerm_linux_virtual_machine" "bootstrap_vm" {  
 
  name                            = "bootstrap-vm"
  resource_group_name             = azurerm_resource_group.tkg_resource_group.name
  location                        = azurerm_resource_group.tkg_resource_group.location
  size                            = var.bootstrap_vm_size
  admin_username                  = var.bootstrap_username
  admin_password                  = var.bootstrap_password
  disable_password_authentication = false
  
  network_interface_ids = [
    azurerm_network_interface.bootstrap_nic.id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  connection {
    host     = self.public_ip_address
    user     = self.admin_username
    password = self.admin_password
  }

  # Seperate shell so user inherits the groupadd in the following shell to run docker as non-root
  provisioner "remote-exec" {
    inline = [
      "ls",
    ]

  }

  # Commands:

  # "wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v${var.pivnet_version}/pivnet-linux-amd64-${var.pivnet_version}",
  #     "chmod 755 pivnet-linux-amd64-${var.pivnet_version}",
  #     "sudo mv pivnet-linux-amd64-${var.pivnet_version} /usr/local/bin/pivnet",
  #     "pivnet login --api-token=${var.pivnet_api_token}",
  #     "pivnet download-product-files --product-slug='tanzu-application-platform' --release-version='${var.tap_version}' --glob='tanzu-framework-linux-amd64-*.tar'",
  #     "tar xvf tanzu-framework-*-amd64-*.tar",
  #     "sudo install cli/core/v${var.tanzu_cli_version}/tanzu-core-*_amd64 /usr/local/bin/tanzu",
  #     "export TANZU_CLI_NO_INIT=true",
  #     "tanzu version",
  #     "tanzu plugin install --local cli all",
  #     "rm -f tanzu-framework-*-amd64-*.tar",
  #     "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl",
  #     "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
      
    
}
