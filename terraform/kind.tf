# Replace this file and the provider blocks below to bootstrap an existing
# cluster instead.

resource "kind_cluster" "this" {
  name       = var.cluster_name
  node_image = "kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
  # kind adds the kind-<cluster_name> context and makes it current;
  # terraform destroy removes it.
  kubeconfig_path = pathexpand("~/.kube/config")
  wait_for_ready  = true
}

provider "helm" {
  kubernetes = {
    host                   = kind_cluster.this.endpoint
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  }
}

provider "kubernetes" {
  host                   = kind_cluster.this.endpoint
  client_certificate     = kind_cluster.this.client_certificate
  client_key             = kind_cluster.this.client_key
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
}
