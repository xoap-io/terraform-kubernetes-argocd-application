module "this_label" {
  source     = "git::github.com/xoap-io/terraform-aws-misc-label?ref=v0.1.0"
  context    = var.context
  attributes = [var.name]
}

resource "kubernetes_manifest" "argo_application" {

  computed_fields = [
    "metadata.labels",
    "metadata.annotations",
    "metadata.finalizers",
    "spec.source.helm.version",
    "spec.source.helm.parameters"

  ]
  field_manager {
    # force field manager conflicts to be overridden
    force_conflicts = true
  }
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = module.this_label.id
      namespace  = var.argocd_namespace
      labels     = local.labels
      finalizers = var.cascade_delete == true ? ["resources-finalizer.argocd.argoproj.io"] : []
      annotations = var.annotations
    }
    spec = {
      project = var.project
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        chart          = var.chart
        path           = var.path
        helm = {
          releaseName = var.release_name == null ? module.this_label.id : var.release_name
          parameters  = local.helm_parameters
          values      = yamlencode(merge({ labels = local.labels }, var.helm_values))
        }
      }
      destination = {
        server    = var.destination_server
        namespace = var.namespace
      }
      ignoreDifferences = var.ignore_differences
      syncPolicy = {
        automated = {
          prune    = var.automated_prune
          selfHeal = var.automated_self_heal
        }
        syncOptions = concat(var.sync_options, [
          var.sync_option_validate ? "Validate=true" : "Validate=false",
          var.sync_option_create_namespace ? "CreateNamespace=true" : "CreateNamespace=false",
        ])
        retry = {
          limit = var.retry_limit
          backoff = {
            duration    = var.retry_backoff_duration
            factor      = var.retry_backoff_factor
            maxDuration = var.retry_backoff_max_duration
          }
        }
      }
      ignoreDifferences = var.ignore_differences
    }
  }


}
