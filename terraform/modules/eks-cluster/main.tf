resource "aws_eks_cluster" "eks" {
  name     = local.name
  role_arn = aws_iam_role.iamrc.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.sn[*].id
    endpoint_public_access  = var.cluster_endpoint_public_access
    endpoint_private_access = false
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.iamrcpa]

  tags = var.tags
}

resource "aws_eks_node_group" "eksng" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${local.name}-ng"
  node_role_arn   = aws_iam_role.iamrn.arn
  subnet_ids      = aws_subnet.sn[*].id

  instance_types = var.instance_types
  capacity_type  = "ON_DEMAND"
  disk_size      = var.disk_size

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.iamrnp_worker,
    aws_iam_role_policy_attachment.iamrnp_cni,
    aws_iam_role_policy_attachment.iamrnp_ecr,
  ]

  tags = var.tags
}
