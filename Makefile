.PHONY: all init plan apply destroy build push deploy clean help

# Variables
ENVIRONMENT ?= dev
AWS_REGION ?= us-east-1
IMAGE_TAG ?= latest

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

#--------------------------------------------------------------
# Help
#--------------------------------------------------------------
help:
	@echo "$(GREEN)AWS EKS CI/CD Pipeline - Makefile Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Terraform Commands:$(NC)"
	@echo "  make init        - Initialize Terraform"
	@echo "  make plan        - Create Terraform plan"
	@echo "  make apply       - Apply Terraform configuration"
	@echo "  make destroy     - Destroy infrastructure"
	@echo ""
	@echo "$(YELLOW)Docker Commands:$(NC)"
	@echo "  make build       - Build Docker image"
	@echo "  make push        - Push image to ECR"
	@echo ""
	@echo "$(YELLOW)Kubernetes Commands:$(NC)"
	@echo "  make deploy      - Deploy to Kubernetes"
	@echo "  make logs        - View application logs"
	@echo "  make shell       - Shell into running pod"
	@echo "  make port-forward - Forward local port to service"
	@echo ""
	@echo "$(YELLOW)Other Commands:$(NC)"
	@echo "  make test        - Run tests"
	@echo "  make clean       - Clean up local resources"
	@echo ""
	@echo "$(YELLOW)Variables:$(NC)"
	@echo "  ENVIRONMENT=$(ENVIRONMENT) (dev|staging|prod)"
	@echo "  AWS_REGION=$(AWS_REGION)"

#--------------------------------------------------------------
# Terraform Commands
#--------------------------------------------------------------
init:
	@echo "$(GREEN)Initializing Terraform...$(NC)"
	cd terraform && terraform init

plan:
	@echo "$(GREEN)Creating Terraform plan...$(NC)"
	cd terraform && terraform plan -out=tfplan

apply:
	@echo "$(GREEN)Applying Terraform configuration...$(NC)"
	cd terraform && terraform apply tfplan

destroy:
	@echo "$(RED)Destroying infrastructure...$(NC)"
	cd terraform && terraform destroy

fmt:
	@echo "$(GREEN)Formatting Terraform files...$(NC)"
	cd terraform && terraform fmt -recursive

validate:
	@echo "$(GREEN)Validating Terraform configuration...$(NC)"
	cd terraform && terraform validate

#--------------------------------------------------------------
# Docker Commands
#--------------------------------------------------------------
build:
	@echo "$(GREEN)Building Docker image...$(NC)"
	cd app && docker build -t eks-cicd-app:$(IMAGE_TAG) .

push:
	@echo "$(GREEN)Pushing Docker image to ECR...$(NC)"
	$(eval ECR_REGISTRY := $(shell terraform -chdir=terraform output -raw ecr_repository_urls | jq -r '.app'))
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	docker tag eks-cicd-app:$(IMAGE_TAG) $(ECR_REGISTRY):$(IMAGE_TAG)
	docker push $(ECR_REGISTRY):$(IMAGE_TAG)

#--------------------------------------------------------------
# Kubernetes Commands
#--------------------------------------------------------------
kubeconfig:
	@echo "$(GREEN)Updating kubeconfig...$(NC)"
	$(eval CLUSTER_NAME := $(shell terraform -chdir=terraform output -raw eks_cluster_name))
	aws eks update-kubeconfig --name $(CLUSTER_NAME) --region $(AWS_REGION)

deploy: kubeconfig
	@echo "$(GREEN)Deploying to Kubernetes ($(ENVIRONMENT))...$(NC)"
	kubectl apply -k kubernetes/overlays/$(ENVIRONMENT)

rollback: kubeconfig
	@echo "$(YELLOW)Rolling back deployment...$(NC)"
	kubectl rollout undo deployment/$(ENVIRONMENT)-app -n app-$(ENVIRONMENT)

logs: kubeconfig
	@echo "$(GREEN)Fetching application logs...$(NC)"
	kubectl logs -f -l app=app -n app-$(ENVIRONMENT) --tail=100

shell: kubeconfig
	@echo "$(GREEN)Opening shell in pod...$(NC)"
	kubectl exec -it $$(kubectl get pods -n app-$(ENVIRONMENT) -l app=app -o jsonpath='{.items[0].metadata.name}') -n app-$(ENVIRONMENT) -- /bin/sh

port-forward: kubeconfig
	@echo "$(GREEN)Forwarding port 8080 to service...$(NC)"
	kubectl port-forward svc/$(ENVIRONMENT)-app 8080:80 -n app-$(ENVIRONMENT)

status: kubeconfig
	@echo "$(GREEN)Cluster status:$(NC)"
	kubectl get nodes
	@echo ""
	@echo "$(GREEN)Deployments:$(NC)"
	kubectl get deployments -A
	@echo ""
	@echo "$(GREEN)Pods:$(NC)"
	kubectl get pods -A
	@echo ""
	@echo "$(GREEN)Services:$(NC)"
	kubectl get svc -A

#--------------------------------------------------------------
# Testing Commands
#--------------------------------------------------------------
test:
	@echo "$(GREEN)Running tests...$(NC)"
	cd app && pip install -r requirements.txt
	cd app && pytest tests/ -v --cov=.

test-docker:
	@echo "$(GREEN)Running tests in Docker...$(NC)"
	docker run --rm eks-cicd-app:$(IMAGE_TAG) python -m pytest tests/ -v

lint:
	@echo "$(GREEN)Linting code...$(NC)"
	cd app && pip install flake8
	cd app && flake8 . --max-line-length=120

#--------------------------------------------------------------
# Utility Commands
#--------------------------------------------------------------
clean:
	@echo "$(YELLOW)Cleaning up...$(NC)"
	docker rmi eks-cicd-app:$(IMAGE_TAG) || true
	find . -type d -name "__pycache__" -exec rm -rf {} + || true
	find . -type f -name "*.pyc" -delete || true
	rm -rf terraform/.terraform || true
	rm -f terraform/tfplan || true

trivy-scan:
	@echo "$(GREEN)Running Trivy security scan...$(NC)"
	trivy image eks-cicd-app:$(IMAGE_TAG)

all: init plan apply build push deploy
	@echo "$(GREEN)Full deployment complete!$(NC)"
