terraform {
  required_version = ">= 0.11.7"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

provider "vault" {
  address = "${var.vault_addr}"
}

data "vault_generic_secret" "azure_credentials" {
  path = "secret/${var.vault_user}/azure/credentials"
}

resource "vault_auth_backend" "k8s" {
  type = "kubernetes"
  path = "${var.vault_user}-aks-${var.environment}"
  description = "Vault Auth backend for Kubernetes"
}

provider "azurerm" {
  subscription_id = "${data.vault_generic_secret.azure_credentials.data["subscription_id"]}"
  tenant_id       = "${data.vault_generic_secret.azure_credentials.data["tenant_id"]}"
  client_id       = "${data.vault_generic_secret.azure_credentials.data["client_id"]}"
  client_secret   = "${data.vault_generic_secret.azure_credentials.data["client_secret"]}"
}

# Azure Resource Group
resource "azurerm_resource_group" "k8sexample" {
  name     = "${var.resource_group_name}"
  location = "${var.azure_location}"
}

# Azure Container Service (AKS) Cluster
resource "azurerm_kubernetes_cluster" "k8sexample" {
  name = "${var.cluster_name}"
  location = "${azurerm_resource_group.k8sexample.location}"
  resource_group_name = "${azurerm_resource_group.k8sexample.name}"
  dns_prefix = "${var.dns_prefix}"
  kubernetes_version = "${var.k8s_version}"

  linux_profile {
    admin_username = "${var.admin_user}"
    ssh_key {
      key_data = "${chomp(tls_private_key.ssh_key.public_key_openssh)}"
    }
  }

  agent_pool_profile {
    name       = "${var.agent_pool_name}"
    count      =  "${var.agent_count}"
    os_type    = "${var.os_type}"
    os_disk_size_gb = "${var.os_disk_size}"
    vm_size    = "${var.vm_size}"
  }

  service_principal {
    client_id     = "${data.vault_generic_secret.azure_credentials.data["client_id"]}"
    client_secret = "${data.vault_generic_secret.azure_credentials.data["client_secret"]}"
  }

  tags {
    Environment = "${var.environment}"
  }
}

/*resource "null_resource" "get_config" {
  provisioner "local-exec" {
    command = "echo '${chomp(tls_private_key.ssh_key.private_key_pem)}' > private_key.pem"
  }
  provisioner "local-exec" {
    command = "chmod 600 private_key.pem"
  }
  provisioner "local-exec" {
    command = "sleep 120"
  }
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i private_key.pem azureuser@${azurerm_kubernetes_cluster.k8sexample.fqdn}:~/.kube/config config"
  }
  provisioner "local-exec" {
    command = "sed -n 6,6p config | cut -d '\"' -f 2 > ca_certificate"
  }
  provisioner "local-exec" {
    command = "sed -n 19,19p config | cut -d '\"' -f 2 > client_certificate"
  }
  provisioner "local-exec" {
    command = "sed -n 20,20p config | cut -d '\"' -f 2 > client_key"
  }
}

data "null_data_source" "get_certs" {
  inputs = {
    client_certificate = "${file("client_certificate")}"
    client_key = "${file("client_key")}"
    ca_certificate = "${file("ca_certificate")}"
  }
  depends_on = ["null_resource.get_config"]
}

resource "null_resource" "auth_config" {
  provisioner "local-exec" {
    command = "curl --header \"X-Vault-Token: $VAULT_TOKEN\" --header \"Content-Type: application/json\" --request POST --data '{ \"kubernetes_host\": \"https://${azurerm_kubernetes_cluster.k8sexample.fqdn}:443\", \"kubernetes_ca_cert\": \"${chomp(replace(base64decode(data.null_data_source.get_certs.outputs["ca_certificate"]), "/\\r\n/", "\\n"))}\" }' ${var.vault_addr}/v1/auth/${vault_auth_backend.k8s.path}config"
  }
}

resource "vault_generic_secret" "role" {
  path = "auth/${vault_auth_backend.k8s.path}role/demo"
  data_json = <<EOT
  {
    "bound_service_account_names": "cats-and-dogs",
    "bound_service_account_namespaces": "default",
    "policies": "${var.vault_user}",
    "ttl": "24h"
  }
  EOT
} */
