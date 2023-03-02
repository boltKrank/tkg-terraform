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

  # Send files:
  provisioner "file" {  
    source = "${path.cwd}/../binaries/" 
    destination = "/home/${var.bootstrap_username}/" 
  }


  # Seperate shell so user inherits the groupadd in the following shell to run docker as non-root
  provisioner "remote-exec" {
    inline = [
      "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash",   
      "az login --service-principal -u ${var.sp_client_id} -p ${var.sp_secret} --tenant ${var.sp_tenant_id}",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo groupadd docker",
      "sudo usermod -aG docker $USER",
      "echo 'END DOCKER INSTALL'",
      "sudo sysctl net/netfilter/nf_conntrack_max=131072",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd",
      "mkdir tanzu",
      "cd tanzu",
      "mv tanzu-cli-bundle-linux-amd64.tar.gz tanzu",
      "tar -xvf tanzu-cli-bundle-linux-amd64.tar.gz",
      "sudo install core/v0.28.0/tanzu-core-linux_amd64 /usr/local/bin/tanzu",
      "tanzu init",
      "tanzu version",
      "tanzu plugin sync",
      "tanzu plugin list",
      "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl",
      "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
      "cd $HOME/tanzu/cli",
      "gunzip ytt-linux-amd64-v0.43.1+vmware.1.gz",
      "chmod ugo+x ytt-linux-amd64-v0.43.1+vmware.1",
      "sudo mv ./ytt-linux-amd64-v0.43.1+vmware.1 /usr/local/bin/ytt",
      "ytt --version",
      "gunzip kapp-linux-amd64-v0.53.2+vmware.1.gz",
      "chmod ugo+x kapp-linux-amd64-v0.53.2+vmware.1",
      "sudo mv ./kapp-linux-amd64-v0.53.2+vmware.1 /usr/local/bin/kapp",
      "kapp --version",
      "gunzip kbld-linux-amd64-v0.35.1+vmware.1.gz",
      "chmod ugo+x kbld-linux-amd64-v0.35.1+vmware.1",
      "sudo mv ./kbld-linux-amd64-v0.35.1+vmware.1 /usr/local/bin/kbld",
      "kbld --version",
      "gunzip imgpkg-linux-amd64-v0.31.1+vmware.1.gz",
      "chmod ugo+x imgpkg-linux-amd64-v0.31.1+vmware.1",
      "sudo mv ./imgpkg-linux-amd64-v0.31.1+vmware.1 /usr/local/bin/imgpkg",
      "imgpkg --version",
    ]
  }
}