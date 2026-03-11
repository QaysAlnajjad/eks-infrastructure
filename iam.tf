/*=================================================================
  IAM role for EKS Control Plane.
  AWS uses this role when:
    - Creating cluster
    - Modifying networking
    - Link control plane with VPC
    - Creating managed ENIs
  This role means AWS manages Kubernetes itself
=================================================================*/
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}


/*=================================================================
  IAM role for Worker Nodes (Node Group).
  EC2 instances (worker nodes) use it when:
    - Booting node
    - kubelet connects with EKS API
    - CNI plugin creates pod ENI
    - Node pulls an image
  This role means OS/Node-level permissions
=================================================================*/

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


/*=================================================================
  EKS OIDC Provider
  Only one pod uses this role when:
    - Creating/updating ingress
    - Service type = LoadBalancer
    - Annotations change
  This role means application-level AWS integration
=================================================================*/

data "aws_eks_cluster" "this" {
  name = aws_eks_cluster.this.name
}

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd8e9c6"]
}

resource "aws_iam_policy" "alb_controller" {
  name = "eks-alb-controller-policy"

  policy = file("${path.module}/alb-controller-policy.json")
}

locals {
  oidc_provider = replace(
    data.aws_eks_cluster.this.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

resource "aws_iam_role" "alb_controller" {
  name = "eks-alb-controller-role"
  assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }
  ]
})

}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
