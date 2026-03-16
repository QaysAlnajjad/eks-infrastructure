# EKS Infrastructure (Terraform)

This repository provisions the AWS infrastructure required to run the Kubernetes platform and GitOps workflow.

It creates the complete base environment for the observability platform and applications using **Terraform**.

---

## Architecture

Terraform provisions the following AWS resources:

- VPC
- Public and private subnets
- Internet Gateway
- Route tables
- EKS Cluster
- Managed Node Groups
- IAM roles and policies
- Security groups
- OIDC provider for IAM roles for service accounts

After the infrastructure is created, the cluster becomes the target environment for GitOps deployments managed by **ArgoCD**.

---

## Repository Structure
