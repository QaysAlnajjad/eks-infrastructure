# eks-infrastructure

Terraform repository for provisioning the AWS and EKS foundation used by the platform.

This repository is responsible for creating the Kubernetes infrastructure layer and the initial bootstrap resources needed before the GitOps applications repository takes over.

## Purpose

This repository provisions and bootstraps:

- AWS networking for the cluster
- Amazon EKS cluster and node group
- IAM roles and policies
- OIDC / IRSA-related infrastructure
- initial cluster access mapping
- initial GitOps bootstrap handoff

The goal of this repository is to prepare a working EKS environment, then hand application delivery over to the GitOps repository.

## Repository Structure

```text
eks-infrastructure/
├── .github/workflows/        # CI/CD workflows for infra deployment
|   |── deploy-infra.yaml
|   └── destroy-infra.yaml 
├── bootstrap/                # Initial bootstrap resources and Terraform bootstrap logic
│   ├── aws-auth.yaml
│   ├── main.tf
│   ├── providers.tf
│   ├── root-app.yaml
│   └── variables.tf
├── scripts/                  # Helper scripts for apply / destroy / operational tasks
|   ├── config.sh
|   ├── deploy-infra.sh
|   └── destroy-infra.sh
├── RUNBOOR.md                # Infrastructure runbook
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

2. Cluster bootstrap

The bootstrap/ directory contains the initial resources required to connect the newly created cluster with the GitOps workflow.

This includes:

    * aws-auth.yaml for cluster access mapping

    * root-app.yaml for bootstrapping the root ArgoCD application

    * bootstrap Terraform files used during the initial handoff

3. Helper operations

    * The scripts/ directory contains helper automation for deployment, cleanup, and destroy operations

---

## Workflow

The expected lifecycle is:

  1. Provision AWS + EKS using Terraform from this repository

  2. Configure cluster access

  3. Apply bootstrap resources

  4. Let ArgoCD point to the GitOps repository

  5. Manage all Kubernetes applications from eks-gitops-apps

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
RUNBOOR.md
```

## Notes

  * This repository focuses on infrastructure and initial bootstrap only.

  * Ongoing application changes should be made in the GitOps repository, not here.

  * Destroy operations should account for Kubernetes-managed AWS resources such as ALBs before Terraform teardown.

## Author

Qays Alnajjad
















