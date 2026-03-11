//=================================================================================================================
// OIDC provider
//=================================================================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}


//=================================================================================================================
// kubernetes-ci-infra-role
//=================================================================================================================

resource "aws_iam_role" "ci_infra" {
  name = "kubernetes-ci-infra-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ci_infra_admin" {
  role = aws_iam_role.ci_infra.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


//=================================================================================================================
// eks_cluster_access
//=================================================================================================================

resource "aws_iam_policy" "eks_cluster_access" {
  name = "eks-cluster-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = "*"
      }
    ]
  })
}


//=================================================================================================================
// kubernetes-deploy-app-ci-role
//=================================================================================================================

resource "aws_iam_role" "ci_app" {
  name = "kubernetes-ci-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ci_app_attach" {
  role = aws_iam_role.ci_app.name
  policy_arn = aws_iam_policy.eks_cluster_access.arn
}


//=================================================================================================================
// kubernetes-ci-monitoring-role
//=================================================================================================================

resource "aws_iam_role" "ci_monitoring" {
  name = "kubernetes-ci-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ci_monitoring_attach" {
  role = aws_iam_role.ci_monitoring.name
  policy_arn = aws_iam_policy.eks_cluster_access.arn
}