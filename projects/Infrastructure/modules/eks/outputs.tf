output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.eks.certificate_authority[0].data
}

output "node_group_name" {
  value = aws_eks_node_group.node_group.node_group_name
}

output "node_group_arn" {
  value = aws_eks_node_group.node_group.arn
}

output "node_group_status" {
  value = aws_eks_node_group.node_group.status
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer" {
  value = replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")
}

output "lbc_role_arn" {
  value = aws_iam_role.lbc_irsa.arn
}
