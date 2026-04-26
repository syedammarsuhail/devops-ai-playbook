output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_urls" {
  value = module.ecr.repository_urls
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
  description = "Run this after terraform apply to configure kubectl"
}

output "next_steps" {
  value = <<-EOT
    Terraform apply complete. Your cluster is ready.

    1. kubectl is already configured (done by Terraform).
    2. ArgoCD is syncing all manifests from GitHub automatically.
    3. Run CI/CD (build-blue-green workflow) in GitHub Actions to push images.

    ArgoCD URL:  http://<argocd-server-elb>   (check: kubectl get svc argocd-server -n argocd)
    App URL:     http://<frontend-ingress-elb> (check: kubectl get ingress -n boutique)
    Password:    kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
  EOT
  description = "Post-apply instructions"
}
