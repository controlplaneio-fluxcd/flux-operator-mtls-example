output "kube_context" {
  description = "Kubeconfig context of the kind cluster."
  value       = kind_cluster.this.context_name
}
