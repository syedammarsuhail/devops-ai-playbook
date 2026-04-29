terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# Namespaces

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# ArgoCD — exposed as LoadBalancer, insecure mode for HTTP access

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.0"

  create_namespace = false
  cleanup_on_fail  = true
  timeout          = 600
  wait             = false

  values = [
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
          }
        }
        extraArgs = ["--insecure"]
      }
    })
  ]

  depends_on = [null_resource.wait_for_lbc]
}

# kube-prometheus-stack monitoring

resource "helm_release" "monitoring" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "56.21.0"

  timeout          = 600
  create_namespace = false

  values = [
    yamlencode({
      grafana = {
        service = { type = "ClusterIP" }
      }
      prometheus = {
        service = { type = "ClusterIP" }
      }
      alertmanager = {
        service = { type = "ClusterIP" }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.monitoring]
}

# AWS Load Balancer Controller ServiceAccount with IRSA annotation

resource "kubernetes_service_account_v1" "lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.lbc_role_arn
    }
  }
}

# AWS Load Balancer Controller Helm release

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.region
      vpcId       = var.vpc_id
      serviceAccount = {
        create = false
        name   = "aws-load-balancer-controller"
      }
    })
  ]

  depends_on = [kubernetes_service_account_v1.lbc]
}

# Wait for LBC webhook pod to be ready before installing anything that uses LoadBalancer services
resource "null_resource" "wait_for_lbc" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region} && kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s"
  }

  depends_on = [helm_release.lbc]
}

# Apply ArgoCD Application after ArgoCD is ready — triggers GitOps auto-sync

resource "null_resource" "argocd_app" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}
      kubectl apply -f ${path.root}/../../gitops/argo-cd.yml
    EOT
  }

  depends_on = [helm_release.argocd]

  triggers = {
    argocd_version = helm_release.argocd.version
  }
}
