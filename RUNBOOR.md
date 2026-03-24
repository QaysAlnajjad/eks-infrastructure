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

### CI/CD Responsibility Boundaries

```text
| Workflow             | IAM Role                       | Kubernetes Permissions           |
|----------------------|--------------------------------|------------------------------ ---|
| deploy-infra         | kubernetes-ci-infra-role       | Cluster bootstrap (one-time)	   |
| deploy-app           | kubernetes-ci-app-role         | Namespace-scoped                 |
```
---

### Why Infrastructure Bootstrap Uses Cluster-Admin

The infrastructure bootstrap process (`deploy-infra`) performs one-time cluster initialization tasks that require elevated privileges.

This includes:
- Installing Kubernetes CRDs (Prometheus Operator, Alertmanager)
- Creating ClusterRoles and ClusterRoleBindings
- Installing Helm charts that create cluster-scoped resources
- Configuring aws-auth for IAM → Kubernetes mapping
- Deploying controllers such as AWS Load Balancer Controller

Because these actions affect the cluster globally, the bootstrap pipeline is intentionally granted cluster-admin permissions.

To reduce risk:
- Bootstrap is executed only during initial provisioning
- Application and monitoring workflows operate with restricted, namespace-scoped permissions
- No day-to-day deployment pipeline has cluster-admin access

### Separation Between Bootstrap and Day-2 Operations

This project intentionally separates:
- **Bootstrap responsibilities** (cluster creation, controllers, CRDs)
- **Day-2 operations** (application deployment, monitoring configuration)

This mirrors real-world production environments where:
- Platform teams own cluster initialization
- Application teams operate with least privilege
- Monitoring changes do not require full administrative access

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

