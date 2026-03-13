#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/config.sh"

echo "Checking backend S3 bucket..."
if ! aws s3 ls "s3://$TF_STATE_BUCKET_NAME" --region "$TF_STATE_BUCKET_REGION" >/dev/null 2>&1; then
  aws s3 mb "s3://$TF_STATE_BUCKET_NAME" --region "$TF_STATE_BUCKET_REGION"

  aws s3api put-bucket-versioning \
    --bucket "$TF_STATE_BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$TF_STATE_BUCKET_REGION"
fi

echo "Running Terraform init..."
terraform init -reconfigure -upgrade \
  -backend-config="bucket=$TF_STATE_BUCKET_NAME" \
  -backend-config="key=EKS-project/terraform.tfstate" \
  -backend-config="region=$TF_STATE_BUCKET_REGION"

echo "Running Terraform apply..."
terraform apply \
  -var aws_region="$AWS_REGION" \
  -var cluster_name="$CLUSTER_NAME" \
  -var-file="terraform.tfvars" \
  --auto-approve

echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --wait

echo "Applying ArgoCD root application..."
kubectl apply -f bootstrap/root-app.yaml

echo "Bootstrap completed successfully."
echo "Current ArgoCD pods:"
kubectl get pods -n argocd

echo "ArgoCD applications (may take a short time to appear):"
kubectl get applications -n argocd || true
