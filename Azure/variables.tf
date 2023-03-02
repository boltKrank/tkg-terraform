### Account variables

variable "subscription_id" {
  type = string
  # sensitive = true
}

variable "subscription_name" {
  type = string
  # sensitive = true
}

### Other variables
variable "resource_group" {
  description = "Resource group name"
  default = "tkg-rg"
}

variable "location" {
  description = "The Azure Region in which all resources should be created."
}

### Bootstrap box

variable "bootstrap_username" {
  description = "Password for bootsrap box"
}

variable "bootstrap_password" {
  description = "Password for bootsrap box"
}

variable "bootstrap_vm_size" {
  description = "Password for bootsrap box"
  default = "Standard_B2s"
}

variable "tanzu_registry_hostname" {
  description = "URL for Tanzu registry"
}


variable "tanzu_registry_username" {
  description = "Username for Tanzu registry"
}


variable "tanzu_registry_password" {
  description = "Password for Tanzu registry"
}

variable "pivnet_version" {
  description = "The version of pivnet CLI to install"
  default = "3.0.1"
}

variable "pivnet_api_token" {
  description = "API Token for Pivnet"
}

variable "tanzu_cli_version" {
  description = "Tanzu CLI version"
  default = "0.25.4"
}

