#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/config.sh"

echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

echo "Getting cluster VPC ID..."
VPC_ID="$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)"

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "Failed to detect VPC ID for cluster $CLUSTER_NAME"
  exit 1
fi

echo "Cluster VPC ID: $VPC_ID"

echo "Deleting all Ingress resources in all namespaces..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true || true

echo "Deleting LoadBalancer services in all namespaces..."
while read -r NS NAME TYPE; do
  if [ "$TYPE" = "LoadBalancer" ]; then
    echo "Deleting Service $NS/$NAME"
    kubectl delete svc "$NAME" -n "$NS" --ignore-not-found=true || true
  fi
done < <(kubectl get svc -A \
  -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type \
  --no-headers 2>/dev/null || true)

echo "Waiting for Kubernetes/AWS controller cleanup..."
sleep 90

echo "Looking for ALBs in VPC $VPC_ID related to cluster $CLUSTER_NAME ..."
LB_ARNS="$(aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --query "LoadBalancers[?VpcId=='$VPC_ID' && Type=='application'].LoadBalancerArn" \
  --output text || true)"

for LB_ARN in $LB_ARNS; do
  [ -z "$LB_ARN" ] && continue

  TAG_VALUE="$(aws elbv2 describe-tags \
    --region "$AWS_REGION" \
    --resource-arns "$LB_ARN" \
    --query "TagDescriptions[0].Tags[?Key=='kubernetes.io/cluster/$CLUSTER_NAME'].Value | [0]" \
    --output text 2>/dev/null || true)"

  if [ "$TAG_VALUE" = "owned" ] || [ "$TAG_VALUE" = "shared" ]; then
    echo "Deleting ALB: $LB_ARN"
    aws elbv2 delete-load-balancer \
      --region "$AWS_REGION" \
      --load-balancer-arn "$LB_ARN" || true
  fi
done

echo "Waiting for ALBs to be deleted..."
sleep 60

echo "Looking for Target Groups in VPC $VPC_ID related to cluster $CLUSTER_NAME ..."
TG_ARNS="$(aws elbv2 describe-target-groups \
  --region "$AWS_REGION" \
  --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" \
  --output text || true)"

for TG_ARN in $TG_ARNS; do
  [ -z "$TG_ARN" ] && continue

  TAG_VALUE="$(aws elbv2 describe-tags \
    --region "$AWS_REGION" \
    --resource-arns "$TG_ARN" \
    --query "TagDescriptions[0].Tags[?Key=='kubernetes.io/cluster/$CLUSTER_NAME'].Value | [0]" \
    --output text 2>/dev/null || true)"

  if [ "$TAG_VALUE" = "owned" ] || [ "$TAG_VALUE" = "shared" ]; then
    echo "Deleting Target Group: $TG_ARN"
    aws elbv2 delete-target-group \
      --region "$AWS_REGION" \
      --target-group-arn "$TG_ARN" || true
  fi
done

echo "Running Terraform destroy..."
terraform init -reconfigure -upgrade \
  -backend-config="bucket=$TF_STATE_BUCKET_NAME" \
  -backend-config="key=EKS-project/terraform.tfstate" \
  -backend-config="region=$TF_STATE_BUCKET_REGION"

terraform destroy \
  -var aws_region="$AWS_REGION" \
  -var cluster_name="$CLUSTER_NAME" \
  -var-file="terraform.tfvars" \
  --auto-approve
