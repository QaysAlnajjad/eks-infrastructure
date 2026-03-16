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
1. Core AWS infrastructure

This layer includes the base AWS resources required for EKS, such as:

VPC

subnets

routing

EKS control plane

worker node group

IAM roles and policies

2. Cluster bootstrap

The bootstrap/ directory contains the initial resources required to connect the newly created cluster with the GitOps workflow.

This includes:

aws-auth.yaml for cluster access mapping

root-app.yaml for bootstrapping the root ArgoCD application

bootstrap Terraform files used during the initial handoff

3. Helper operations

The scripts/ directory contains helper automation for deployment, cleanup, and destroy operations




















