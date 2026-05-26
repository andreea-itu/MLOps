output "data" {
  description = "EKS cluster object"
  value       = aws_eks_cluster.eks
}

output "node_group" {
  description = "EKS managed node group object"
  value       = aws_eks_node_group.eksng
}

output "vpc_id" {
  description = "VPC ID used by the cluster"
  value       = aws_vpc.vpc.id
}

output "subnet_ids" {
  description = "Public subnet IDs used by the cluster and node group"
  value       = aws_subnet.sn[*].id
}
