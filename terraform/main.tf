module "flux_operator_bootstrap" {
  source     = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  version    = "0.9.0"
  depends_on = [kind_cluster.this]

  revision         = var.revision
  debug_on_failure = var.debug_on_failure

  gitops_resources = {
    instance_yaml = file("${path.root}/../clusters/kind/flux-system/flux-instance.yaml")

    # SPIRE must run before the operator: the operator pod mounts the SPIFFE
    # CSI socket and needs its SVID to build a FluxInstance with mTLS.
    prerequisites = {
      yamls = [
        file("${path.root}/../infrastructure/spire/namespace.yaml"),
      ]
      charts = [
        {
          name             = "spire-crds"
          repository       = "ghcr.io/spiffe/helm-charts/spire-crds"
          version          = "0.6.1"
          namespace        = "spire-system"
          create_namespace = false
        },
        {
          name             = "spire"
          repository       = "ghcr.io/spiffe/helm-charts/spire"
          version          = "0.30.4"
          namespace        = "spire-system"
          create_namespace = false
          values_yaml      = file("${path.root}/../infrastructure/spire/spire-values.yaml")
          flux_adoption_check = {
            resource  = "statefulsets"
            api_group = "apps"
            name      = "spire-server"
            namespace = "spire-system"
          }
        },
      ]
    }

    operator_chart = {
      version     = "0.62.0"
      values_yaml = file("${path.root}/../clusters/kind/flux-system/flux-operator-values.yaml")
    }
  }

  managed_resources = {
    secrets_yaml = <<-YAML
      apiVersion: v1
      kind: Secret
      metadata:
        name: receiver-token
      type: Opaque
      stringData:
        token: '${replace(var.receiver_token, "'", "''")}'
    YAML
    runtime_info = {
      labels = {
        "reconcile.fluxcd.io/watch" = "Enabled"
      }
      data = {
        git_ref = var.git_ref
      }
    }
  }
}
