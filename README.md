# DevOps AI Playbook

A production-grade DevOps project featuring microservices on AWS EKS, GitOps with ArgoCD, blue-green deployments, Prometheus/Grafana monitoring, and an AIOps assistant powered by AWS Bedrock — fully automated with Terraform and GitHub Actions.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                     GitHub Actions CI/CD                          │
│  Push → Build Docker Images → Push to ECR → Update Manifests     │
└───────────────────────────┬──────────────────────────────────────┘
                            │ GitOps sync (ArgoCD)
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                        AWS EKS Cluster                            │
│                                                                    │
│   ┌──────────────┐   ┌────────────────────────────────────────┐  │
│   │    ArgoCD    │──▶│             boutique namespace          │  │
│   │   (GitOps)   │   │                                        │  │
│   └──────────────┘   │  ┌──────────┐  ┌──────────────────┐  │  │
│                       │  │ Postgres │  │   ALB Ingress    │  │  │
│   ┌──────────────┐   │  └──────────┘  └───────┬──────────┘  │  │
│   │  Prometheus  │   │                          │             │  │
│   │  + Grafana   │   │   ┌───────────────────┐  │             │  │
│   └──────────────┘   │   │  Gateway  :3001   │◀─┤ /api        │  │
│                       │   └────────┬──────────┘  │             │  │
│   ┌──────────────┐   │            │              │             │  │
│   │  AIOps Kira  │   │   ┌────────▼───────────┐  │             │  │
│   │  (Bedrock)   │   │   │ Auth │Orders│Product│  │             │  │
│   └──────────────┘   │   └────────────────────┘  │             │  │
│                       │                            │             │  │
│                       │   ┌────────────────────┐  │             │  │
│                       │   │  Blue  │   Green   │◀─┘  /          │  │
│                       │   │  Frontend (React)  │               │  │
│                       │   └────────────────────┘               │  │
│                       └────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Application | React, Node.js, PostgreSQL |
| Containers | Docker |
| Orchestration | Kubernetes (AWS EKS 1.34) |
| Infrastructure | Terraform |
| CI/CD | GitHub Actions |
| GitOps | ArgoCD + Kustomize |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Log Forwarding | Fluent Bit → AWS CloudWatch |
| Load Balancing | AWS Load Balancer Controller (ALB) |
| AIOps | AWS Bedrock Agent + Lambda |

---

## Repository Structure

```
devops-ai-playbook/
├── .github/
│   └── workflows/
│       ├── ci.yml                     # Build all 7 microservices → ECR + manifest update
│       └── build-blue-green.yml       # Build frontend :blue and :green images
├── gitops/
│   ├── argo-cd.yml                    # ArgoCD Application manifest
│   ├── kustomization.yml              # Kustomize entry point
│   └── k8s/
│       ├── backend/                   # Gateway, Auth, Orders, Products, Users YAMLs
│       ├── frontend/                  # Blue-green Deployments + Ingress
│       └── database/                  # PostgreSQL StatefulSet + restore Job
├── projects/
│   ├── Infrastructure/                # Terraform — all AWS resources
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars           # Edit this before applying
│   │   └── modules/
│   │       ├── vpc/                   # VPC, subnets, IGW, route tables
│   │       ├── eks/                   # EKS cluster, node group, OIDC, IAM
│   │       ├── ecr/                   # ECR repositories
│   │       └── argocd/                # LBC, ArgoCD, Prometheus, namespaces
│   ├── boutique-microservices/        # Application source code (7 services)
│   │   ├── frontend/                  # React app + Dockerfile
│   │   └── backend/
│   │       └── services/
│   │           ├── auth/
│   │           ├── gateway/
│   │           ├── orders/
│   │           ├── order-service/
│   │           ├── product-service/
│   │           └── user-service/
│   └── aiops-assistant/               # AIOps Bedrock agent
│       └── lambda/
│           └── fetch_health/          # Lambda: EKS + Prometheus health checks
└── docs/
    ├── part1-system-design.md
    └── part2-workflow.md
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| AWS CLI | v2+ (configured with `aws configure`) |
| Terraform | >= 1.5 |
| kubectl | Latest |
| Docker | Latest |

### Required GitHub Secrets

Go to **Settings → Secrets and variables → Actions** in your fork:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | e.g. `ca-central-1` |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `DOCKERHUB_USERNAME` | Docker Hub username (optional) |
| `DOCKERHUB_PASSWORD` | Docker Hub password (optional) |

---

## Quick Start

### Step 1 — Fork and clone

```bash
git clone https://github.com/<your-username>/devops-ai-playbook.git
cd devops-ai-playbook
```

### Step 2 — Configure Terraform

Edit `projects/Infrastructure/terraform.tfvars` to match your target region and preferences. No secrets go here — just region, CIDR blocks, and instance types.

### Step 3 — Deploy infrastructure

```bash
cd projects/Infrastructure
terraform init
terraform apply -auto-approve
```

This provisions in a single command (~15 minutes):

- VPC with 3 public subnets across availability zones
- EKS cluster (Kubernetes 1.34) with 2x `m7i-flex.large` worker nodes
- 7 ECR repositories (one per microservice)
- AWS Load Balancer Controller with IRSA
- ArgoCD exposed via internet-facing ALB
- kube-prometheus-stack (Prometheus + Grafana)
- EBS CSI driver addon

### Step 4 — Get cluster access

```bash
aws eks update-kubeconfig --name eks-cluster --region <your-region>
kubectl get nodes
```

### Step 5 — Build and push images

In GitHub → Actions, run:

1. **Boutique CI Pipeline** — builds all 7 microservices, pushes to ECR with SHA tag, updates manifests
2. **Build Blue-Green Frontend** — builds `frontend:blue` (v1) and `frontend:green` (v2)

### Step 6 — Deploy the application

ArgoCD auto-syncs from GitHub. If you want to trigger it immediately:

```bash
kubectl apply -f gitops/argo-cd.yml
```

Watch pods come up:
```bash
kubectl get pods -n boutique -w
```

### Step 7 — Access your app

```bash
# App URL
kubectl get ingress -n boutique

# ArgoCD URL
kubectl get svc argocd-server -n argocd

# ArgoCD password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

---

## Blue-Green Deployment

Both frontend versions run simultaneously. Cut traffic between them by changing one line in git — ArgoCD applies the change within ~30 seconds, zero downtime.

**`gitops/k8s/frontend/blue-green.yml`**

```yaml
spec:
  selector:
    app: frontend
    version: blue      # ← change to "green" to cut over
```

Commit and push. That's it.

```
Blue  (v1) ──▶ live traffic
Green (v2) ──▶ idle, pre-warmed, ready for instant rollout
```

To switch programmatically:

```bash
# Switch to green
sed -i 's/version: blue      # ← change to "green"/version: green     # ← change to "blue"/' \
  gitops/k8s/frontend/blue-green.yml
git add gitops/k8s/frontend/blue-green.yml && git commit -m "chore: cut over to green" && git push

# Switch back to blue
sed -i 's/version: green     # ← change to "blue"/version: blue      # ← change to "green"/' \
  gitops/k8s/frontend/blue-green.yml
git add gitops/k8s/frontend/blue-green.yml && git commit -m "chore: cut over to blue" && git push
```

---

## CI/CD Pipeline

```
Developer pushes code
        │
        ▼
GitHub Actions — ci.yml
  ├── Build Docker image (matrix: 7 services in parallel)
  ├── Push :latest and :<sha> tags to ECR
  └── Update gitops/k8s/ manifests with new SHA
        │
        ▼ (auto-push to main)
ArgoCD detects git change
        │
        ▼
Rolling update on EKS — zero downtime
```

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` | `workflow_dispatch` | Builds all 7 services, pushes to ECR, updates manifests |
| `build-blue-green.yml` | `workflow_dispatch` | Builds `frontend:blue` and `frontend:green` |

> To enable on push: change `workflow_dispatch` to `push: branches: [main]` in the workflow files.

---

## Monitoring

Prometheus and Grafana are deployed in the `monitoring` namespace via kube-prometheus-stack.

```bash
kubectl get svc -n monitoring
```

Access Grafana at the LoadBalancer URL on port 80.

**Default credentials:** `admin` / `prom-operator`

Pre-built dashboards:
- Kubernetes cluster overview
- Pod CPU & memory
- Deployment replica health
- Node metrics

---

## AIOps Assistant (Kira)

An AWS Bedrock Agent that answers natural language DevOps questions:

> "Is the EKS cluster healthy?"
> "Are there any crashing pods?"
> "What's the replica status for the orders service?"

**How it works:**

1. Bedrock Agent receives a natural language query
2. Invokes Lambda (`projects/aiops-assistant/lambda/fetch_health/`)
3. Lambda queries EKS via AWS SDK + Prometheus via PromQL
4. Returns structured health data back to the agent
5. Agent responds in plain English

**Setup:**

1. Deploy infrastructure (Step 3 above)
2. Update `PROMETHEUS_URL` in `lambda_function.py` with your Prometheus ELB:
   ```bash
   kubectl get svc -n monitoring | grep prometheus
   ```
3. Deploy the Lambda and configure the Bedrock Agent — see `projects/aiops-assistant/README.md`

---

## Troubleshooting

**Pods in `ErrImagePull`**

The CI workflow hasn't run yet, or manifests point to wrong SHA.

```bash
# Check what tags exist in ECR
aws ecr describe-images --repository-name auth --region <region>

# Run the CI workflow in GitHub Actions, then update manifests
```

**Backend pods in `CrashLoopBackOff`** (database not found)

```bash
# Create application databases
for db in auth_db orders_db products_db users_db; do
  kubectl exec -n boutique boutique-postgres-0 -- psql -U postgres -c "CREATE DATABASE $db;"
done
```

**ArgoCD not picking up changes**

```bash
kubectl annotate application boutique -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

**`kubectl patch` gets reverted**

ArgoCD auto-sync overwrites manual kubectl changes. Always change git files instead — ArgoCD is the source of truth.

**Subnet stuck deleting (`terraform destroy`)**

AWS LBC creates load balancers that leave orphaned ENIs.

```bash
# Find lingering ENIs
aws ec2 describe-network-interfaces --region <region> \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query "NetworkInterfaces[*].[NetworkInterfaceId,Status]" --output table

# Delete them
aws ec2 delete-network-interface --region <region> --network-interface-id <eni-id>

# Then retry destroy
terraform destroy -auto-approve
```

---

## Teardown

```bash
# Clean up Kubernetes resources first (avoids stuck namespace finalizers)
kubectl delete application boutique -n argocd --ignore-not-found
kubectl delete namespace boutique argocd monitoring --force --grace-period=0

# Remove namespaces from Terraform state (already deleted above)
cd projects/Infrastructure
terraform state rm module.argocd.kubernetes_namespace_v1.argocd

# Destroy everything
terraform destroy -auto-approve
```

---

## License

MIT
