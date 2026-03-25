# Kubernetes Platform on AWS (EKS)

## Purpose

This runbook documents operational procedures for monitoring, troubleshooting, and maintaining the EKS-based Kubernetes platform.

The goal is to demonstrate production-style operational readiness, including:

  * Incident response

  * Root cause analysis

  * Monitoring-driven decisions

  * Secure and controlled remediation steps

---

## Platform Overview

  * Cloud Provider: AWS

  * Kubernetes: Amazon EKS (managed control plane)

  * Ingress: AWS ALB via AWS Load Balancer Controller

  * CI/CD: GitHub Actions with OIDC (no static credentials)

  * Monitoring: kube-prometheus-stack (Prometheus, Alertmanager, Grafana)

---

## Monitoring & Alerting

Active Alerts

```
| Alert Name           | Purpose                                                                |
|----------------------| -----------------------------------------------------------------------|
| HighRequestLatency   | Detect degraded user experience caused by slow application responses   |	
```

Alert Condition
```bash
95th percentile request latency > 1s for 3 minutes
```
This alert is intentionally conservative to avoid noise and focus on user-impacting issues.

---

## Incident Response Procedures

Incident: HighRequestLatency
Symptoms

  * Alert HighRequestLatency is firing

  * Users may experience slow responses

  * No immediate pod crashes observed

### Step-by-Step Investigation

1️⃣ Confirm the Alert

  * Open Grafana dashboard

  * Verify:

    * Request latency (p95)

    * Error rate

    * Request volume

2️⃣ Identify Affected Components

```bash
kubectl get pods -n app
kubectl get svc -n app
kubectl get ingress -n app
```

Check:

  * Pod restarts

  * Readiness probe failures

  * Deployment replica count

3️⃣ Inspect Application Pods

```bash
kubectl describe pod <pod-name> -n app
kubectl logs <pod-name> -n app
```

Look for:

  * CPU throttling

  * Memory pressure

  * Slow downstream dependencies

  * Application-level bottlenecks

4️⃣ Check Resource Utilization

```bash
kubectl top pods -n app
kubectl top nodes
```

Indicators:

  * High CPU usage

  * Node resource exhaustion

  * Imbalanced pod scheduling

5️⃣ Validate Autoscaling Behavior

```bash
kubectl get hpa -n app
kubectl describe hpa <hpa-name> -n app
```
Confirm:

  * HPA is scaling correctly

  * Metrics server is functioning

  * Desired vs current replicas

---

## Mitigation Actions
Immediate Mitigation

  * Increase replicas manually if required
```bash
kubectl scale deployment app --replicas=<N> -n app
```

  * If a recent deployment occurred:
```bash
kubectl rollout undo deployment app -n app
```

Post-Mitigation Validation

  * Confirm alert clears

  * Verify latency returns to baseline

  * Monitor error rates for 10–15 minutes

---

## Failure Scenarios & Expected Behavior

🔁 Pod CrashLoop

Action

```bash
kubectl delete pod <pod-name> -n app
```
Expected Behavior

  * Deployment recreates pod

  * Service routing remains intact

  * No alert unless latency degrades

🔻 Node Failure

Action

  * Terminate EC2 node manually (simulated)

Expected Behavior

  * Pods rescheduled onto healthy nodes

  * Temporary latency spike possible

  * Alert only triggers if degradation persists

---

## Security & Access Model

IAM → Kubernetes Authorization

  * AWS IAM roles mapped via aws-auth ConfigMap

  * Kubernetes RBAC enforces authorization

  * No static AWS credentials used anywhere

---

### Access Model

  * **deploy-infra** workflow uses the IAM role kubernetes-ci-infra-role, mapped through aws-auth to system:masters, to perform initial cluster bootstrap tasks.
  * **eks-node-role** is mapped to allow worker nodes to join and operate in the cluster.
  * **admin-cli** provides manual administrative access for break-glass or operational debugging.
  * **ArgoCD** permissions are not defined through aws-auth; they are granted through Kubernetes service accounts and RBAC inside the cluster

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

## Conclusion

This runbook demonstrates:

  * Real-world incident handling

  * Monitoring-driven troubleshooting

  * Secure operational boundaries

  * Production-oriented thinking

The platform is designed for clarity, safety, and operational correctness, not feature overload

---

