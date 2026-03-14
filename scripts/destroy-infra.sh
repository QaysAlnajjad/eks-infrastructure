
#!/bin/bash

set -e
source "$(dirname "$0")/config.sh"

# 1. Kubernetes resources that create AWS infra 
aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $CLUSTER_NAME
kubectl delete ingress --all || true
kubectl delete svc --all || true
echo "Waiting for AWS to clean up ENIs..."
sleep 90

# 2. Terraform
terraform init -reconfigure -upgrade \
    -backend-config="bucket=$TF_STATE_BUCKET_NAME" \
    -backend-config="key=EKS-project/terraform.tfstate" \
    -backend-config="region=$TF_STATE_BUCKET_REGION"

terraform destroy \
    -var aws_region=$AWS_REGION \
    -var cluster_name=$CLUSTER_NAME \
    -var-file="terraform.tfvars" \
    --auto-approve
