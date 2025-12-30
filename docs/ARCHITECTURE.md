# Architecture Overview

This document provides an in-depth look at the AWS EKS CI/CD pipeline architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    Developer                                         │
│                                        │                                             │
│                                        ▼                                             │
│                              ┌──────────────────┐                                   │
│                              │    Git Push      │                                   │
│                              └────────┬─────────┘                                   │
│                                       │                                              │
│                                       ▼                                              │
│                     ┌─────────────────────────────────────┐                         │
│                     │         GitHub / Jenkins            │                         │
│                     │         CI/CD Pipeline              │                         │
│                     └───────────────────┬─────────────────┘                         │
│                                         │                                            │
│   ┌─────────────────────────────────────┼─────────────────────────────────────┐     │
│   │                                     │                                      │     │
│   │  ┌──────────────┐   ┌──────────────┐│┌──────────────┐   ┌──────────────┐  │     │
│   │  │   Build &    │   │   Security   │││   Push to    │   │  Deploy to   │  │     │
│   │  │   Test       │──▶│   Scan       │──▶│   ECR        │──▶│   EKS        │  │     │
│   │  └──────────────┘   └──────────────┘│└──────────────┘   └──────────────┘  │     │
│   │                                     │                                      │     │
│   └─────────────────────────────────────┼─────────────────────────────────────┘     │
│                                         │                                            │
│                                         ▼                                            │
│                              ┌──────────────────┐                                   │
│                              │   Amazon EKS     │                                   │
│                              │   Cluster        │                                   │
│                              └────────┬─────────┘                                   │
│                                       │                                              │
│                                       ▼                                              │
│                             ┌──────────────────┐                                    │
│                             │     Users        │                                    │
│                             └──────────────────┘                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Networking (VPC Module)

The VPC module creates a production-ready network architecture:

```
VPC (10.0.0.0/16)
├── Public Subnets (2 AZs)
│   ├── 10.0.1.0/24 (us-east-1a)
│   └── 10.0.2.0/24 (us-east-1b)
├── Private Subnets (2 AZs)
│   ├── 10.0.10.0/24 (us-east-1a)
│   └── 10.0.11.0/24 (us-east-1b)
├── Internet Gateway
├── NAT Gateways (2 for HA)
└── Route Tables
```

**Why this design?**
- Public subnets for load balancers
- Private subnets for EKS worker nodes (security)
- NAT Gateways for outbound internet access from private subnets
- Multi-AZ for high availability

### 2. Amazon EKS Cluster

**Control Plane:**
- Managed by AWS
- Runs Kubernetes API server, etcd, scheduler
- Multi-AZ by default

**Node Group:**
- Managed node group with auto-scaling
- Runs in private subnets
- Instance type: t3.medium (configurable)
- Disk: 50GB EBS

**OIDC Provider:**
- Enables IAM Roles for Service Accounts (IRSA)
- Pods can assume specific IAM roles

### 3. Amazon ECR

- Private container registry
- Image scanning enabled (Trivy integration)
- Lifecycle policies for image cleanup
- Encryption at rest

### 4. IAM Roles

| Role | Purpose |
|------|---------|
| EKS Cluster Role | Allows EKS to manage AWS resources |
| Node Group Role | Allows worker nodes to join cluster |
| Jenkins Role (IRSA) | For CI/CD pipeline to push images and deploy |
| ALB Controller Role (IRSA) | For AWS Load Balancer Controller |
| External DNS Role (IRSA) | For DNS record management |

### 5. CI/CD Pipeline

**Jenkins Pipeline Stages:**
1. **Checkout** - Clone source code
2. **Build** - Build Docker image
3. **Test** - Run unit tests
4. **Security Scan** - Trivy vulnerability scan
5. **Push** - Push to ECR
6. **Deploy** - Update Kubernetes deployment

**GitHub Actions Workflow:**
- Same stages as Jenkins
- Environment-based deployments
- Production requires approval

## Data Flow

### Deployment Flow

```
1. Developer pushes code to GitHub
                │
                ▼
2. CI/CD pipeline triggered
                │
                ▼
3. Docker image built from code
                │
                ▼
4. Image scanned for vulnerabilities
                │
                ▼
5. Image pushed to Amazon ECR
                │
                ▼
6. Kubernetes deployment updated
                │
                ▼
7. EKS pulls new image from ECR
                │
                ▼
8. New pods scheduled on worker nodes
                │
                ▼
9. ALB routes traffic to new pods
                │
                ▼
10. Application available to users
```

### Request Flow

```
User Request
     │
     ▼
Internet Gateway
     │
     ▼
Application Load Balancer (in public subnet)
     │
     ▼
Target Group (IP mode)
     │
     ▼
EKS Pod (in private subnet)
     │
     ▼
Response returned to user
```

## Security Architecture

### Network Security

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                           │
├─────────────────────────────────────────────────────────────┤
│ 1. AWS WAF (optional)           - Web application firewall  │
│ 2. Security Groups              - Instance-level firewall   │
│ 3. Network ACLs                 - Subnet-level firewall     │
│ 4. Kubernetes Network Policies  - Pod-level firewall        │
│ 5. Pod Security Standards      - Container restrictions     │
└─────────────────────────────────────────────────────────────┘
```

### IAM Security

- Least privilege principle
- IRSA for pod-level IAM permissions
- No long-term credentials in pods
- Audit logging enabled

### Container Security

- Image scanning in ECR
- Trivy scanning in CI/CD
- Non-root container execution
- Read-only filesystem (where possible)

## Scaling

### Horizontal Pod Autoscaler (HPA)

```yaml
Metrics:
  - CPU: target 70% utilization
  - Memory: target 80% utilization

Scaling:
  - Min replicas: 2 (prod: 3)
  - Max replicas: 10 (prod: 20)
```

### Cluster Autoscaler

- Automatically scales node group
- Min nodes: 1
- Max nodes: 5
- Scales based on pending pods

## Monitoring Stack

```
┌───────────────────────────────────────────────────────────┐
│                  Monitoring Architecture                   │
├───────────────────────────────────────────────────────────┤
│                                                            │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────┐  │
│   │  Prometheus  │────▶│   Grafana    │────▶│  Users   │  │
│   │  (metrics)   │     │ (dashboards) │     │          │  │
│   └──────────────┘     └──────────────┘     └──────────┘  │
│          ▲                                                 │
│          │                                                 │
│   ┌──────┴──────┐                                         │
│   │             │                                         │
│   ▼             ▼                                         │
│ ┌────────┐  ┌────────┐                                    │
│ │  Pods  │  │ Nodes  │                                    │
│ └────────┘  └────────┘                                    │
│                                                            │
└───────────────────────────────────────────────────────────┘
```

## Cost Optimization

1. **Use Spot Instances** - Up to 90% savings for non-prod
2. **Right-size instances** - Use t3.medium for dev
3. **Single NAT Gateway** - For dev/staging environments
4. **Scheduled scaling** - Scale down during off-hours
5. **ECR lifecycle policies** - Delete old images
