# Kubernetes Monitoring with Prometheus & Alertmanager

## Overview

This project demonstrates a production-style monitoring setup for a Flask application running on Kubernetes (EKS) using:

  * Prometheus for metrics collection

  * Alertmanager for alert delivery

  * Grafana for visualization

  * Prometheus Operator (kube-prometheus-stack)

The focus of the project is application latency monitoring using histograms and alerting based on percentile (P95).

⚠️ Note: Some values (such as alert thresholds) are intentionally low to force alerts during testing/demo. These values are explained explicitly and should be adjusted in real production environments.

***See RUNBOOK.md for operational procedures and incident handling.***

---

# Table of Contents

- [Architecture](#architecture)
- [Application](#application)
- [Why Histogram?](#why-histogram)
- [Alerting](#alerting)
- [AlertManager](#alertmanager)
- [Architecture](#architecture)
- [Load Testing (Demo)](#load-testing-demo)
- [Repository Structure](#repository-structure)
- [Deployment & Execution](#deployment--execution)
- [Demo Videos](#demo-videos)
- [What This Project Demonstrates](#what-this-project-demonstrates)
- [Production Considerations](#production-considerations)
- [Conclusion](#conclusion)

--- 

## Architecture
```bash
Client
  |
  v
AWS ALB
  |
  v
app-service (HTTP :80)
  |
  v
Flask Pods
  ├── App Server (:8080)
  └── Metrics Server (:9090) ──> metrics-service
  |                                 |
  |                                 v
  |                             Prometheus
  |                                 |
  |                                 v
  |                            Alertmanager
  |
  v
Grafana

```

Why two Services?

| Service              | Purpose                                             |
| ---------------------| --------------------------------------------------- |
| `app-service`        | Serves user traffic via ALB                         |
| `metrics-service`    | Exposes `/metrics` endpoint **only** for Prometheus |

---

## Application

The application is a simple Flask API that exposes:

  - / – basic endpoint

  - /work?delay=N – simulates work by sleeping N seconds

  - /metrics – Prometheus metrics endpoint

Metrics exposed
```bash
Histogram(
  "app_request_duration_seconds",
  "Request latency",
  ["path"]
)
```
This histogram allows Prometheus to compute latency percentiles (P50, P90, P95, …).

---

## Why Histogram?

Percentiles cannot be calculated from averages.

A histogram allows Prometheus to answer questions like:

  * “What is the 95th percentile latency?”

  * “Are a small number of requests extremely slow?”

This project intentionally uses

```bash
histogram_quantile(
  0.95,
  sum by (le) (
    rate(app_request_duration_seconds_bucket[5m])
  )
)
```

Prometheus cannot calculate percentiles from averages, even if the average looks reasonable.

---

## Alerting

Alert rule
```bash
alert: HighRequestLatency
expr: |
  histogram_quantile(
    0.95,
    sum by (le) (
      rate(app_request_duration_seconds_bucket[5m])
    )
  ) > 0.5
for: 3m
```
Important ⚠️

  * 0.5s threshold is deliberately low

  * Used only for demo/testing

  * In real production, typical values might be:

    - 1.5s

    - 2s

    - or higher depending on SLA

---

## Alertmanager

Alertmanager is fully enabled and configured via Helm values.

Alerts are routed using standard Alertmanager configuration

  * Not disabled

  * Not using null receivers

  * Designed to demonstrate real alert flow

  * The project validates that:

    - Prometheus evaluates rules

    - Alerts fire

    - Alertmanager receives them

---

## Load Testing (Demo)

To trigger alerts:
```bash
for i in {1..50}; do
  curl "http://<ALB>/work?delay=1"
done
```
This generates sustained latency > 0.5s, causing the alert to fire after 3 minutes.

⚠️ Port-Forward Note

During heavy load testing, you may see errors like:

```bash
portforward.go: Timeout occurred
```
This is normal behavior when:

  * Prometheus is under load

  * Many concurrent scrapes occur

It does NOT indicate:

  * Alert failure

  * Prometheus crash

  * Configuration error

---

## Repository Structure

```bash
├── k8s/
│   ├── app/
│   │   ├── deployment.yaml
│   │   ├── app-service.yaml
│   │   ├── metrics-service.yaml
│   │   └── ingress.yaml
│   ├── monitoring/
│   │   ├── values.yaml
│   │   ├── namespace.yaml
│   │   ├── servicemonitors/
│   │   │   └── flask.yaml
│   │   ├── dashboards/
│   │   └── alerts/
│   │       ├── alertmanager-config.yaml
│   │       └── app-alerts.yaml
│   ├── rbac/
│   │   ├── app-role.yaml
│   │   ├── monitoring-cluster-role.yaml
│   │   ├── monitoring-helm-role.yaml
│   │   └── rolebinding.yaml
│   └── bootstrap/
│       ├── alb-controller-serviceaccount.yaml
│       └── aws-auth.yaml
├── terraform/
└── script/
    ├── config.sh
    ├── deploy-infra.sh
    └── destroy-infra.sh
```

---

## Deployment & Execution

This project supports two execution modes:

  * Local execution (manual, from your machine)

  * GitHub Actions execution (CI/CD workflows)

Before either mode, you must of course clone the repository.

--- 

### Clone the Repository

```bash
git clone https://github.com/qaysalnajjad/aws-kubernetes-monitoring.git
cd aws-kubernetes-monitoring
```

All paths and commands below assume you are inside the repository root.

---

### Configure AWS Credentials

Authentication is done using IAM Roles (OIDC) via GitHub Actions or locally via AWS CLI.

Locally (example):
```bash
aws configure
```
Or ensure environment variables are set:
```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=eks-cluster
```

---

### Phase 0 — Bootstrap (Required only for GitHub Actions)

This step is required before any GitHub Actions deployment.

Why Bootstrap Exists

Bootstrap is responsible for:

  * Creating the GitHub OIDC provider in AWS

  * Creating IAM roles trusted by GitHub Actions

  * Eliminating the need for AWS access keys in CI/CD

Because bootstrap itself requires AWS credentials, it cannot and must not be executed inside GitHub Actions.

Running it in CI/CD would defeat its purpose and reintroduce secret management.

How Bootstrap Is Executed

Bootstrap is executed locally using Terraform:

```bash
terraform -chdir=terraform/bootstrap apply
```
This step is performed once per AWS account / environment.

After bootstrap is complete:

  * GitHub Actions can securely assume IAM roles via OIDC

  * No AWS secrets are stored in workflows

---

### Option A — Local Deployment

This mode uses local tools and credentials.

Requirements

  * AWS credentials configured locally

  * Installed tools:

    - terraform

    - awscli

    - kubectl

    - helm

Flow

1. Provision infrastructure:
```bash
./scripts/deploy-infra.sh
```
This script:

  * Creates / verifies Terraform S3 backend

  * Provisions VPC and EKS

  * Configures kubectl access

  * Installs kube-prometheus-stack via Helm

  * Applies ServiceMonitors and PrometheusRules

2. Deploy the application:

```bash
kubectl apply -f k8s/app/deployment.yaml
kubectl apply -f k8s/app/app-service.yaml
kubectl apply -f k8s/app/metrics-service.yaml
kubectl apply -f k8s/app/ingress.yaml
```
Verify pods:
```bash
kubectl get pods
```
Expected:
```bash
    flask-app pods → Running
```
This mode is useful for:

  * Development

  * Debugging

  * Learning and experimentation

---

### Option B — GitHub Actions (CI/CD)

This is the recommended execution mode once bootstrap is complete.

Prerequisite

  * Phase 0 (Bootstrap) must already be executed locally

Without bootstrap, all workflows will fail.

Key Characteristics

  * No AWS access keys stored in GitHub

  * Authentication via OIDC + IAM roles

  * No need for terraform / awscli locally

Workflows Overview

| Workflow            | Purpose                     | IAM Role                       |
| --------------------| ----------------------------|--------------------------------|
| deploy-infra        | Provision EKS & monitoring  | kubernetes-ci-infra-role       |  
| deploy-application  | Deploy Flask app            | kubernetes-ci-app-role         |
| deploy-monitoring   | Deploy Prometheus           | kubernetes-ci-monitoring-role  |

All workflows run aws eks update-kubeconfig internally before executing kubectl/helm commands.

Execution

All workflows are triggered manually:

Actions → Select workflow → Run workflow

Each workflow:

  * Assumes its IAM role via OIDC

  * Updates kubeconfig

  * Executes only its scoped responsibility

This separation ensures:

  * Least privilege

  * Clear ownership

  * Production-grade CI/CD design

⚠️ Important Architectural Note: Helm & RBAC Separation

Originally, Helm (kube-prometheus-stack) was tested inside the deploy-monitoring workflow. This approach was intentionally abandoned for architectural and security reasons.

The kube-prometheus-stack Helm chart requires cluster-wide permissions, including:

  * CRDs (Prometheus, Alertmanager, ServiceMonitor, PrometheusRule)

  * ClusterRoles & ClusterRoleBindings

  * Webhook configurations

  * StatefulSets (Alertmanager)

Granting these permissions to the kubernetes-ci-monitoring-role would violate the principle of least privilege.

Final Design Decision

  * Helm installation of kube-prometheus-stack is executed only in deploy-infra

  * This workflow uses an infrastructure-level IAM role with elevated permissions

  * deploy-monitoring is intentionally limited to non-destructive monitoring changes (rules, dashboards, configs)

This separation:

  * Preserves strict RBAC boundaries

  * Avoids over-privileged CI roles

  * Mirrors real-world production practices

Summary

  * Bootstrap is mandatory and local-only

  * Local deployment is optional and manual

  * GitHub Actions deployment is secure and recommended

  * CI/CD works only because bootstrap exists

This design intentionally prioritizes security over convenience.

---

### Verify Metrics Exposure

⚠️ Important — Ensure kubeconfig Is Configured

Before running any verification or testing commands, make sure your local kubeconfig is pointing to the correct EKS cluster.

Check that metrics service has endpoints:

```bash
aws eks update-kubeconfig \
  --name eks-cluster \
  --region us-east-1
```
This step is required for:

  * Port-forwarding Prometheus / Alertmanager

  * Running kubectl get pods, svc, ingress

  * Verifying alert rules and metrics

If this step is skipped, kubectl may:

  * Connect to the wrong cluster

  * Fail silently

  * Produce misleading errors

```bash
kubectl get svc metrics-service
kubectl get endpoints metrics-service
```

Expected:

    One or more pod IPs on port 9090

### Verify Prometheus Is Scraping Metrics

Port-forward Prometheus:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Open browser:

```bash
http://localhost:9090
```
In Prometheus UI → Graph, run:

```bash
app_request_duration_seconds_bucket
```

If data appears → metrics scraping works

### Verify Alert Rule Is Loaded

In Prometheus UI → Status → Rules

You should see:

```bash
HighRequestLatency
```

Status:
    inactive (before load test)


### Generate Load (Trigger the Alert)

Use the ALB DNS name from the ingress:

```bash
kubectl get ingress
```

Then run:

```bash
for i in {1..50}; do
  curl "http://<ALB-DNS>/work?delay=1"
done
```

What this does

  - Forces request latency ≈ 1 second

  - P95 latency exceeds 0.5s

  - Condition sustained for 3 minutes

### Expected Result (IMPORTANT)

After ~3 minutes:

  * Alert state transitions:

    - inactive → pending → firing

  * Alert visible in:

    - Prometheus UI

    - Alertmanager UI (if configured)

The 0.5s threshold is intentionally low for demo/testing only.

### Verify Alertmanager (Optional)

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
```

open:

```bash
http://localhost:9093
```

You should see:

  HighRequestLatency alert firing


Notes on Port-Forward Errors

During heavy testing, you may see:

```bash
Timeout occurred (portforward.go)
```

This is normal under load and does not mean:

  Prometheus is broken

  Alerts failed

  Configuration is invalid


**Note** 

When destroying infrastructure, Kubernetes-managed resources (Ingress / Services) must be deleted first to allow AWS Load Balancer Controller to clean up ALBs and ENIs. Otherwise, Terraform will not be able to delete the VPC.

---

## Demo Videos

    ▶️ Demo 1 (6 min)
    OIDC Bootstrap + deply infra Workflow
    https://www.youtube.com/watch?v=y4VK4MVjFYU&list=PL5EjBcFXdDPAhWIa9WbMPPtx7ldKwSDVc

    ▶️ Demo 2 (9 min)
    deploy app Workflow + Alerting
    https://www.youtube.com/watch?v=f6ehHvG76Ww&list=PL5EjBcFXdDPAhWIa9WbMPPtx7ldKwSDVc&index=2

    All demos were recorded using a sandbox AWS account with GitHub Actions OIDC authentication.
    No static credentials, secrets, or IAM users were used or exposed.

---

## What This Project Demonstrates

  * Proper Prometheus histogram usage

  * Percentile-based alerting (P95)

  * Separation of traffic and metrics services

  * Kubernetes-native monitoring with operators

  * Real alert firing

---

## Production Considerations

If this were production:

  * Increase alert thresholds

  * Tune histogram buckets

  * Add Grafana dashboards

  * Add SLO-based alerts

---

## Conclusion

This project demonstrates:

  * Correct monitoring concepts

  * Real-world alert logic

  * Production-aligned Kubernetes patterns

The low thresholds and aggressive testing are intentional and clearly documented


