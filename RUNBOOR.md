# Infrastructure Bootstrap Runbook

## Purpose

This document defines the security model, access boundaries, and bootstrap procedures for the Kubernetes platform infrastructure on AWS.

It focuses on the initial provisioning phase of the platform, where infrastructure components, access controls, and GitOps foundations are established.

The goal is to provide a clear and controlled approach to:

  * Infrastructure provisioning using Terraform
  * Secure access configuration via AWS IAM and Kubernetes RBAC
  * Initial cluster bootstrap, including ArgoCD installation
  * Establishing privilege boundaries between bootstrap and day-2 operations

This runbook intentionally separates infrastructure bootstrap responsibilities from ongoing operational workflows. It reflects a production-oriented model where:

  * Infrastructure (platform) concerns are handled with elevated privileges during controlled bootstrap phases
  * Continuous deployment and application management are delegated to GitOps workflows with restricted access

This ensures a balance between operational safety, security, and maintainability of the platform.

---

## Security & Access Model

IAM → Kubernetes Authorization

  * AWS IAM roles mapped via aws-auth ConfigMap

  * Kubernetes RBAC enforces authorization

  * No static AWS credentials used anywhere

### Access Model

  * **deploy-infra** workflow uses the IAM role kubernetes-ci-infra-role, mapped through aws-auth to system:masters, to perform initial cluster bootstrap tasks.
  * **eks-node-role** is mapped to allow worker nodes to join and operate in the cluster.
  * **admin-cli** provides manual administrative access for break-glass or operational debugging.
  * **ArgoCD** permissions are not defined through aws-auth; they are granted through Kubernetes service accounts and RBAC inside the cluster

Note: ArgoCD may require cluster-scoped permissions (via Kubernetes RBAC) to manage resources such as CRDs and controllers. These permissions are separate from AWS IAM and are defined within the cluster.

---

### Bootstrap and Privilege Boundaries

deploy-infra is responsible for initial cluster provisioning and bootstrap tasks such as:

  * provisioning AWS and EKS infrastructure
  * updating kubeconfig
  * applying aws-auth
  * installing ArgoCD
  * creating the root ArgoCD application

After bootstrap, ArgoCD takes over reconciliation of platform and application resources from the GitOps repository.

Some of those GitOps-managed resources may be cluster-scoped, such as:

  * CRDs
  * ClusterRoles / ClusterRoleBindings
  * controllers
  * monitoring stack components

Because of that, elevated Kubernetes permissions are required not only during bootstrap, but also for the GitOps control plane when managing cluster-scoped resources.

---

## Cost Awareness

Key cost drivers:

  * NAT Gateway

  * EC2 worker nodes

  * Load Balancer (ALB)

Cost optimizations (production considerations):

  * Spot instances for node groups

  * Cluster Autoscaler

  * Reducing NAT Gateway usage

  * Offloading metrics storage to long-term solutions (e.g. Thanos)

---


