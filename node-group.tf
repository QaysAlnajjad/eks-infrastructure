resource "aws_eks_node_group" "default" {
  cluster_name = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn = aws_iam_role.eks_node_role.arn

  subnet_ids = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size = 3
    min_size = 1
  }

  instance_types = ["t3.medium"]
  capacity_type = "ON_DEMAND"

  ami_type = "AL2_x86_64"

  tags = {
    Name = "${var.project_name}-node-group"
  }

  depends_on = [
    aws_eks_cluster.this
  ]
}
