#!/bin/bash
set -e

source "$(dirname "$0")/config.sh"

echo "Checking backend S3 bucket..."
if ! aws s3 ls "s3://$TF_STATE_BUCKET_NAME" --region "$TF_STATE_BUCKET_REGION" >/dev/null 2>&1; then
  aws s3 mb "s3://$TF_STATE_BUCKET_NAME" --region "$TF_STATE_BUCKET_REGION"
  aws s3api put-bucket-versioning \
    --bucket "$TF_STATE_BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$TF_STATE_BUCKET_REGION"
fi

# 1. Terraform (EKS + VPC)
terraform -chdir="terraform" init -reconfigure -upgrade \
  -backend-config="bucket=$TF_STATE_BUCKET_NAME" \
  -backend-config="key=EKS-project/terraform.tfstate" \
  -backend-config="region=$TF_STATE_BUCKET_REGION"

terraform -chdir="terraform" apply \
  -var aws_region=$AWS_REGION \
  -var cluster_name=$CLUSTER_NAME \
  -var-file="terraform.tfvars" \
  --auto-approve

# 2. kubectl access
aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $CLUSTER_NAME

# 3. Namespaces 
kubectl apply -f k8s/monitoring/namespace.yaml

# 4. IAM ↔ Kubernetes
kubectl apply -f k8s/bootstrap/aws-auth.yaml

# 5. RBAC 
kubectl apply -f k8s/rbac/app-role.yaml
kubectl apply -f k8s/rbac/monitoring-cluster-role.yaml
kubectl apply -f k8s/rbac/monitoring-helm-role.yaml
kubectl apply -f k8s/rbac/rolebinding.yaml

# 6. ALB Controller
kubectl apply -f k8s/bootstrap/alb-controller-serviceaccount.yaml

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 7. Prometheus CRDs
#kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
#kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
#kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
#kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
#kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
#kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml

# 8.Monitoring 
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f k8s/monitoring/values.yaml

# 8.1 Alertmanager routing (CRD-based, production way)
kubectl apply -f k8s/monitoring/alerts/alertmanager-config.yaml


# 9. ServiceMonitoring
kubectl apply -f k8s/monitoring/servicemonitors/

# 10. Apply alerts
kubectl apply -f k8s/monitoring/alerts/


echo "Infrastructure bootstrap completed"
kubectl get nodes
