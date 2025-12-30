# Detailed Setup Guide

This guide provides step-by-step instructions for setting up the AWS EKS CI/CD pipeline.

## Prerequisites

Before you begin, ensure you have the following tools installed:

| Tool | Version | Installation |
|------|---------|--------------|
| AWS CLI | >= 2.0 | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | >= 1.5.0 | [Install Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) |
| kubectl | >= 1.28.0 | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| Docker | >= 24.0 | [Install Guide](https://docs.docker.com/get-docker/) |
| Helm | >= 3.12 | [Install Guide](https://helm.sh/docs/intro/install/) |

## Step 1: AWS Configuration

### 1.1 Configure AWS CLI

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (e.g., `json`)

### 1.2 Verify AWS Access

```bash
aws sts get-caller-identity
```

You should see your account ID and user ARN.

## Step 2: Create Terraform Backend (Optional)

For team collaboration, use S3 backend:

```bash
# Create S3 bucket
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket your-terraform-state-bucket \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

Then update `terraform/backend.tf` to use S3 backend.

## Step 3: Configure Terraform Variables

```bash
cd terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update the following:
- `aws_region`: Your preferred AWS region
- `project_name`: Unique project name
- `environment`: dev, staging, or prod

## Step 4: Deploy Infrastructure

```bash
# Initialize Terraform
make init
# Or: cd terraform && terraform init

# Preview changes
make plan
# Or: cd terraform && terraform plan -out=tfplan

# Apply changes
make apply
# Or: cd terraform && terraform apply tfplan
```

Wait 15-20 minutes for EKS cluster creation.

## Step 5: Configure kubectl

```bash
# Get cluster credentials
aws eks update-kubeconfig --name eks-cicd-dev-eks --region us-east-1

# Verify connection
kubectl get nodes
```

## Step 6: Install AWS Load Balancer Controller

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install ALB Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=eks-cicd-dev-eks \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller
```

## Step 7: Build and Deploy Application

```bash
# Build Docker image
make build

# Push to ECR
make push

# Deploy to Kubernetes
make deploy ENVIRONMENT=dev
```

## Step 8: Access the Application

```bash
# Get Ingress URL
kubectl get ingress -n app-dev

# Or use port-forward for local access
make port-forward ENVIRONMENT=dev
# Then visit: http://localhost:8080
```

## Troubleshooting

### Common Issues

**Issue: `terraform init` fails**
```bash
# Clear Terraform cache
rm -rf terraform/.terraform
terraform init
```

**Issue: `kubectl` can't connect**
```bash
# Re-fetch kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

**Issue: Pods stuck in Pending**
```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check node capacity
kubectl describe nodes
```

**Issue: ALB not created**
```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## Clean Up

To avoid ongoing charges:

```bash
# Delete application
kubectl delete -k kubernetes/overlays/dev

# Destroy infrastructure
make destroy
# Or: cd terraform && terraform destroy
```
