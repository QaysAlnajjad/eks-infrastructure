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
- [What Happens After Bootstrap?](#what-happens-after-bootstrap?)
- [Quick Start](#quick-start)
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
│   └── destroy-infra.yml
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
	•	EKS exists
	•	ArgoCD exists
	•	ArgoCD starts reconciling eks-gitops-apps

That means this repository is the entry point of the platform lifecycle.

---

## What Happens After Bootstrap?

Once the root application is created, ArgoCD begins syncing the apps/ directory from eks-gitops-apps.

From that point onward:
	•	platform apps
	•	workloads
	•	monitoring chart
	•	monitoring resources
	•	Telegram alert webhook

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

### 2. Optional: Configure GitHub Actions OIDC bootstrap

This step is only required if you want to deploy infrastructure via GitHub Actions using OIDC.

Edit bootstrap/main.tf:

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

### 3. Initiate and deploy bootstrap code

```text
cd bootstrap/
terraform init
terraform apply
```

---


### 4. Configure bootstrap/aws-auth.yaml

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

### 5. Configure variables

Edit terraform.tfvars:

```text
cluster_name = "my-eks-cluster"
region       = "us-east-1"
```

---

### 6. Deploy infrastructure

There are two options to deploy infrastructure:

#### 6.1 Locally

```text
chmod +x scripts/deploy-infra.sh
./scripts/deploy-infra.sh
```

### 6.2 GitHub Actions

After pushing the project to your GitHub repository, you can use the flow "deploy-infra" to deploy the infrastructure.

---

### 7. Update Kubeconfig

```text
aws eks update-kubeconfig \
  --region <region_name> \
  --name <cluster_name>
```

---

### 8. Verify cluster

kubectl get nodes

---

### 9. Access ArgoCD

kubectl port-forward svc/argocd-server -n argocd 8080:443

---

### Expected Result

* EKS cluster is running
* ArgoCD is installed
* Root application is created
* Applications from eks-gitops-apps are syncing automatically

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
```tesxt
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
RUNBOOk.md
```

## Notes

  * This repository focuses on infrastructure and initial bootstrap only.

  * Ongoing application changes should be made in the GitOps repository, not here.

  * Destroy operations should account for Kubernetes-managed AWS resources such as ALBs before Terraform teardown.

## Author

Qays Alnajjad
















