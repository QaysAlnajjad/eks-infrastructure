# eks-infrastructure

Terraform repository for provisioning the AWS and EKS foundation used by the platform.

This repository is responsible for creating the Kubernetes infrastructure layer and the initial bootstrap resources needed before ArgoCD takes over application delivery from the GitOps repository.

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

## Repository Structure

```text
eks-infrastructure/
├── .github/workflows/       # CI workflows for deploy / destroy
├── bootstrap/
│   ├── aws-auth.yaml        # initial cluster access mapping
│   ├── root-app.yaml        # root ArgoCD application
│   ├── main.tf
│   ├── providers.tf
│   └── variables.tf
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
















