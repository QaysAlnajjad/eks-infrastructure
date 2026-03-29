# eks-infrastructure

Terraform repository for provisioning the AWS and EKS foundation used by the platform.

This repository is responsible for creating the Kubernetes infrastructure layer and the initial bootstrap resources needed before ArgoCD takes over application delivery from the GitOps repository.

---

# 📘 Table of Contents

- [Overview](#overview)
- [Responsibilities](#responsibilities)
- [Repository Structure](#repository-structure)
- [What this repository manages](#what-this-repository-manages)
- [Bootstrap Flow](#bootstrap-flow)
- [Key Files](#key-files)
- [Deployment Model](#deployment-model)
- [Production Thinking: CI, Security & Trade-offs](#production-thinking-ci-security--trade-offs)
- [What Happens After Bootstrap?](#what-happens-after-bootstrap?)
- [Quick Start](#quick-start)
- [Troubleshooting](#troubleshooting)
- [Related Repository](#related-repository)
- [Relationship to the GitOps repository](#relationship-to-the-gitops-repository)
- [Typical Usage](#typical-usage)
- [Bootstrap handoff](#bootstrap-handoff)  
- [Runbook](#runbook)
- [Notes](#notes)
- [Author](#author)

---

## Overview

This repository builds the base AWS and Kubernetes platform, including:

- VPC and networking
- EKS control plane
- managed node group
- IAM roles and policies
- initial Kubernetes access mapping
- ArgoCD bootstrap handoff to the GitOps applications repository

The handoff happens through the root ArgoCD application defined in `bootstrap/root-app.yaml`, which points to the `apps/` path in the `eks-gitops-apps` repository.

---

## Responsibilities

This repository owns the **infrastructure layer only**.

It is the source of truth for:

- AWS networking and cluster foundation
- IAM / IRSA-related resources required by the platform
- bootstrap manifests needed before GitOps starts reconciling workloads
- helper scripts used to deploy or destroy the environment

It does **not** own long-lived application manifests such as workloads, monitoring resources, or in-cluster application definitions after bootstrap. Those live in `eks-gitops-apps`.

---

## Repository Structure

```text
eks-infrastructure/
├── .github/workflows/       # CI workflows for deploy / destroy
│   ├── deploy-infra.yml
│   ├── destroy-infra.yml
|   └── terraform-pr-checks.yml    
├── bootstrap/
│   ├── aws-auth.yaml        # initial cluster access mapping
│   ├── root-app.yaml        # root ArgoCD application
│   ├── main.tf
│   ├── providers.tf
├── scripts/
│   ├── config.sh
│   ├── deploy-infra.sh
│   └── destroy-infra.sh
├── alb-controller-policy.json
├── backend.tf
├── eks.tf
├── iam.tf
├── node-group.tf
├── outputs.tf
├── providers.tf
├── terraform.tfvars
├── variables.tf
└── vpc.tf
```
---

## What this repository manages

### 1. Core AWS infrastructure

This layer includes the base AWS resources required for EKS, such as:

   * VPC
   * subnets
   * routing
   * EKS control plane
   * worker node group
   * IAM roles and policies

### 2. Cluster bootstrap

The bootstrap/ directory contains the initial resources required to connect the newly created cluster with the GitOps workflow.

This includes:

   * aws-auth.yaml for cluster access mapping
   * root-app.yaml for bootstrapping the root ArgoCD application
   * bootstrap Terraform files used during the initial handoff

### 3. Helper operations

   * The scripts/ directory contains helper automation for deployment, cleanup, and destroy operations

---

## Bootstrap Flow

The infrastructure bootstrap flow is:

 1. Provision AWS resources with Terraform
 2. Update kubeconfig for the new cluster
 3. Apply bootstrap/aws-auth.yaml
 4. Install ArgoCD in the cluster
 5. Apply bootstrap/root-app.yaml
 6. Let ArgoCD sync the application layer from eks-gitops-apps

This repository prepares the cluster; after that, the desired Kubernetes state is managed from Git.

---

## Key Files

### bootstrap/root-app.yaml

Creates the root ArgoCD application:

 * name: platform-root
 * namespace: argocd
 * source repo: eks-gitops-apps
 * source path: apps/

This is the bridge between infrastructure provisioning and GitOps reconciliation.

### bootstrap/aws-auth.yaml

Maps initial IAM identities into Kubernetes RBAC so the cluster can be administered and bootstrapped safely.

### scripts/deploy-infra.sh

Helper script used to initialize/apply Terraform, update kubeconfig, install ArgoCD, and create the root application.


### scripts/destroy-infra.sh

Helper script used to destroy Terraform resources created by deploy-infra.sh script.

---

## Deployment Model

This repo is intended to be applied first.

After a successful infrastructure deployment:
  * EKS exists
  * ArgoCD exists
  * ArgoCD starts reconciling eks-gitops-apps

That means this repository is the entry point of the platform lifecycle.

---

## Engineering Insights & CI Analysis

This repository is not only focused on provisioning infrastructure, but also on demonstrating production-style engineering practices.

As part of the CI pipeline, Terraform code is validated through multiple stages:

* formatting checks (`terraform fmt`)
* validation (`terraform validate`)
* linting (`tflint`)
* security scanning (`tfsec`)

These checks intentionally surface real-world issues that are commonly encountered in production environments.


### Production Thinking: CI, Security & Trade-offs

The following videos document actual pipeline runs, including:

* formatting failures and corrections
* linting issues and best practice violations
* security findings identified by tfsec
* iterative improvements to reach a production-ready baseline

▶️ **EKS-Infrastructure-Terraform-Format-Check** 
https://youtu.be/KGTHxcOkwdg

Terraform Formatting Failures
Cause: inconsistent formatting across Terraform files
Resolution: enforced terraform fmt -check in CI and standardized formatting across the repository

▶️ **EKS-Infrastructure-TFLint-Check** 
https://youtu.be/1rYfRzthVTs

Issue:
  * Missing required_version and provider version constraints
  * Deprecated interpolation syntax (${...})
  * Unused resources in IAM definitions

Resolution:
  * added explicit Terraform and provider version constraints
  * updated syntax to modern Terraform style
  * removed or refactored unused resources

▶️ **EKS-Infrastructure-Terraform-Plan-Check** 
https://youtu.be/VCUeJGv07FI

Error: Backend initialization required during terraform plan
Cause: using remote S3 backend without initializing it in CI

Resolution:
  * removed terraform plan from PR checks
  * kept backend-independent validation steps

### Note on tfsec Findings

Some tfsec findings shown in the walkthrough are intentionally not fully remediated in this iteration.

The goal of this project is to demonstrate awareness of security issues and the ability to prioritize them, rather than to enforce a fully hardened configuration.

In real-world environments, not all findings are addressed immediately. Decisions are made based on impact, cost, and operational context. This repository reflects that approach by highlighting the findings while deferring certain improvements.

### Why `terraform plan/apply` is not part of PR checks

During early iterations, the CI pipeline included `terraform plan` (and apply-related validation) as part of pull request checks.

However, this step was intentionally removed from the PR workflow.

#### Reason

This project uses a **remote S3 backend** for Terraform state. Running `terraform plan` in CI requires:

  * initialized backend configuration
  * access to the S3 state bucket
  * AWS credentials with sufficient permissions
  * environment-specific variables

Including this in PR checks would tightly couple validation with real infrastructure and introduce unnecessary complexity and potential failure points.

#### Decision

To keep PR checks:

  * fast
  * deterministic
  * independent from live infrastructure

the pipeline focuses on:

  * formatting (`terraform fmt`)
  * validation (`terraform validate`)
  * linting (`tflint`)
  * security scanning (`tfsec`)

#### Production Perspective

In real-world environments, `terraform plan/apply` is typically executed in **controlled deployment pipelines**, not in lightweight validation workflows.

This repository reflects that separation by keeping PR checks lightweight and infrastructure execution isolated.




### Engineering Approach

The goal is not to eliminate every warning, but to demonstrate:

* awareness of infrastructure risks
* prioritization of critical vs non-critical issues
* ability to iterate towards production-quality infrastructure

Some findings (e.g., flow logs, IAM simplifications, or medium-level issues) are intentionally left visible to reflect realistic decision-making rather than artificially perfect configurations.

This mirrors how real platforms evolve, where not all issues are fixed at once, but are evaluated based on impact and context.

---

## What Happens After Bootstrap?

Once the root application is created, ArgoCD begins syncing the apps/ directory from eks-gitops-apps.

From that point onward:

  * platform apps
  * workloads
  * monitoring chart
  * monitoring resources
  * Telegram alert webhook

are all managed declaratively from the GitOps repository.

---

## Quick Start

### Prerequisites

* AWS CLI configured
* Terraform >= 1.5
* kubectl installed
* AWS account with sufficient permissions

---

### 1. Clone repository
```text
  git clone https://github.com/QaysAlnajjad/eks-infrastructure.git
  cd eks-infrastructure
```

---

### 2. Optional: Configure and deploy GitHub Actions OIDC bootstrap

This step is only required if you want to deploy infrastructure via GitHub Actions using OIDC.

#### 2.1. Edit bootstrap/main.tf:

```text
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
```

Replace your GitHub repo URL.

Note: bootstrap/aws-auth.yaml is applied automatically by scripts/deploy-infra.sh after the cluster is created and kubeconfig is updated.

---

#### 2.2. Initiate and deploy bootstrap code

```text
cd bootstrap/
terraform init
terraform apply
```

This step only creates the GitHub OIDC provider and IAM role required for CI/CD.

---

### 3. Configure bootstrap/aws-auth.yaml

Edit bootstrap/aws-auth.yaml to replace your AWS account ID:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    # INFRA / CLUSTER ADMIN
    - rolearn: arn:aws:iam::<AWS_ACCOUNT_ID>:role/kubernetes-ci-infra-role
      username: ci:infra
      groups:
        - system:masters

    - rolearn: arn:aws:iam::<AWS_ACCOUNT_ID>:role/eks-node-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes

  mapUsers: |
    - userarn: arn:aws:iam::<AWS_ACCOUNT_ID>:user/admin-cli
      username: admin-cli
      groups:
        - system:masters
```

---

### 4. Configure variables

Edit terraform.tfvars:

```text
cluster_name = "my-eks-cluster"
region       = "us-east-1"
```

---

### 5. Deploy infrastructure

There are two options to deploy infrastructure:

#### 5.1. Locally

```text
chmod +x scripts/deploy-infra.sh
./scripts/deploy-infra.sh
```

### 5.2. GitHub Actions

After pushing the project to your GitHub repository, you can use the flow "deploy-infra" to deploy the infrastructure.

---

Note: The deploy-infra.sh script handles Terraform apply, kubeconfig update, aws-auth configuration, ArgoCD installation, and root application bootstrap.

### 6. (Optional) Update kubeconfig manually if not using the script

```text
aws eks update-kubeconfig \
  --region <region_name> \
  --name <cluster_name>
```

When deploying locally using the script, kubeconfig is updated automatically.

---

### 7. Verify cluster

kubectl get nodes

---

### 8. Access ArgoCD

```text
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Note: ArgoCD RBAC resources (ServiceAccounts, ClusterRoles, and ClusterRoleBindings) are automatically created by the ArgoCD Helm chart during installation.

---

### Expected Result

* EKS cluster is running
* ArgoCD is installed
* Root application is created
* Applications from eks-gitops-apps are syncing automatically

---

## Troubleshooting

If deployment fails, check the following:

  * Terraform errors and state configuration
  * AWS IAM permissions and OIDC setup
  * kubectl connectivity to the cluster
  * ArgoCD pods status: `kubectl get pods -n argocd`
  * Helm installation logs

---

## Related Repository

	• eks-gitops-apps: declarative Kubernetes applications and in-cluster resources managed by ArgoCD

---

## Relationship to the GitOps repository

This repository does not own long-term application delivery.

After the cluster is ready, application deployment is managed from:

  * eks-gitops-apps

In other words:

  * eks-infrastructure = cluster and bootstrap

  * eks-gitops-apps = platform apps and workloads

---

## Typical usage

Initialize Terraform

```text
terraform init
```

plan
```text
terraform plan
```

apply
```text
terraform apply
```

configure kubectl
```text
aws eks update-kubeconfig --region <aws-region> --name <cluster-name>
kubectl get nodes
```

## Bootstrap handoff

After cluster creation, the bootstrap step connects infrastructure to GitOps by applying the required initial manifests from bootstrap/.

That is the point where ArgoCD starts managing the application layer.

## Runbook

Operational procedures and troubleshooting notes are documented in:
```text
RUNBOOK.md
```

## Notes

  * This repository focuses on infrastructure and initial bootstrap only.

  * Ongoing application changes should be made in the GitOps repository, not here.

  * Destroy operations should account for Kubernetes-managed AWS resources such as ALBs before Terraform teardown.

## Author

Qays Alnajjad
















