# CloudPulse — Main Infrastructure

> **Repo 3 of 3** — Deployed **by Jenkins**, not from your laptop. Creates the production AWS infrastructure: VPC, EKS cluster, and ECR registry.

This repository contains the **modular Terraform code** for CloudPulse's main infrastructure, plus the Jenkins pipeline that deploys it with a manual-approval safety gate.

---

## Where This Fits

```
Phase 1 → cloudpulse-bootstrap   → Creates Jenkins + Ansible EC2
Phase 2 → cloudpulse-ansible     → Configures Jenkins
Phase 3 → cloudpulse-infra       → Creates EKS/VPC/ECR (THIS REPO)
```

Unlike the bootstrap repo, this is **not run manually**. Two Jenkins pipelines execute Terraform — a **create** pipeline (`jenkins/Jenkinsfile`) and a separate **destroy** pipeline (`jenkins/Jenkinsfile.destroy`) — each with a human approval step before making changes.

---

## What It Creates

| Module | AWS Resources |
|--------|---------------|
| **vpc** | VPC `10.0.0.0/16`, 2 public + 2 private subnets, Internet Gateway, NAT Gateway, route tables |
| **eks** | EKS cluster, managed node group (`t3.small` x2) on **private** subnets, IAM roles |
| **ecr** | ECR repository for Docker images |

### Network Design

```
Main Infra VPC (10.0.0.0/16)
├── Public Subnets  (10.0.1.0/24, 10.0.2.0/24)
│   ├── LoadBalancer (exposes the app to the internet)
│   └── NAT Gateway  (outbound internet for private nodes)
└── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
    └── EKS Worker Nodes (no public IP — secure)
```

> EKS nodes live in **private subnets** (production best practice). They reach the internet only through the NAT Gateway for pulling images and updates.

---

## Repository Structure

```
cloudpulse-infra/
├── jenkins/
│   ├── Jenkinsfile             # CREATE pipeline: init → validate → plan → approval → apply
│   └── Jenkinsfile.destroy     # DESTROY pipeline: init → plan-destroy → confirm → destroy
└── terraform/
    ├── backend.tf              # S3 remote state + DynamoDB lock + provider versions
    ├── main.tf                 # Wires vpc, eks, ecr modules
    ├── variables.tf            # All input variables (fully parameterized)
    ├── outputs.tf              # Cluster name, ECR URL, subnet IDs
    ├── terraform.tfvars        # Committed — Jenkins uses these values (no secrets)
    ├── terraform.tfvars.example
    └── modules/
        ├── vpc/                # VPC, subnets, IGW, NAT, route tables
        ├── eks/                # EKS cluster + node group + IAM
        └── ecr/                # ECR repository
```

---

## The Jenkins Pipelines

Create and destroy are **two separate Jenkins jobs**, so tearing down infrastructure is always a deliberate, explicit action — never an accidental dropdown option in the normal pipeline.

| Pipeline | Script Path | Purpose |
|----------|-------------|---------|
| **Create** | `jenkins/Jenkinsfile` | `plan` / `apply` infrastructure |
| **Destroy** | `jenkins/Jenkinsfile.destroy` | Tear down all infrastructure |

### Create pipeline (`Jenkinsfile`)

Parameterized with an `ACTION` choice:

| ACTION | Approval Required? | Behavior |
|--------|--------------------|----------|
| `plan` | No | Shows planned changes — safe, read-only |
| `apply` | **Yes** | Creates / updates infrastructure |

```
Checkout → Init → Lint & Validate → Plan → [MANUAL APPROVAL] → Apply → Install FluxCD → Email
```

Every push auto-triggers a `plan`. Nothing is created without a human clicking **"Yes, Proceed"**.

> **Install FluxCD stage (GitOps):** right after the EKS cluster is created, the
> pipeline runs `flux bootstrap github`. This installs Flux into the cluster and
> wires it to the `cloudpulse-app` repo's `k8s/` folder, so the app deploys via
> GitOps from then on. The stage is idempotent (safe to re-run) and needs a
> Jenkins **`github-token`** credential (Secret text, `repo` scope).

### Destroy pipeline (`Jenkinsfile.destroy`)

A dedicated job that first cleans up the Kubernetes layer (Flux + app), then
shows a destroy plan and waits for explicit confirmation:

```
Checkout → Init → Cleanup K8s (Flux + app) → Plan Destroy → [CONFIRM] → Destroy → Email
```

> **Why a Cleanup K8s stage?** Flux and the app's **LoadBalancer** are created
> inside the cluster, **not** by Terraform — so `terraform destroy` can't remove
> them. If left running, the real AWS ELB blocks VPC deletion
> (`DependencyViolation`) and keeps costing money. The stage runs
> `flux uninstall` + `kubectl delete namespace cloudpulse` (best-effort, with
> `|| true`) and waits for the ELB to disappear before Terraform destroys the VPC.

### Running Them

```
# Create / update
Jenkins UI → cloudpulse-infra → Build with Parameters
  → ACTION: plan     → review the plan output
  → ACTION: apply    → approve → infra is created (~15 min for EKS)

# Destroy (separate job)
Jenkins UI → cloudpulse-infra-destroy → Build
  → review destroy plan → confirm → infra is torn down
```

> Set up the destroy job once: New Item → Pipeline → Script Path = `jenkins/Jenkinsfile.destroy`.

---

## Input Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `ap-south-1` | AWS region |
| `project_name` | `cloudpulse` | Naming + tagging prefix |
| `environment` | `production` | Environment label |
| `vpc_cidr` | `10.0.0.0/16` | Main VPC CIDR |
| `public_subnet_cidrs` | `[10.0.1.0/24, 10.0.2.0/24]` | LoadBalancer subnets |
| `private_subnet_cidrs` | `[10.0.10.0/24, 10.0.11.0/24]` | EKS node subnets |
| `cluster_name` | `cloudpulse-cluster` | EKS cluster name |
| `cluster_version` | `1.31` | EKS Kubernetes version (pinned for reproducibility) |
| `node_instance_type` | `t3.small` | Worker node EC2 type |
| `node_desired_size` | `2` | Desired node count |
| `node_min_size` | `1` | Min nodes (autoscaling) |
| `node_max_size` | `3` | Max nodes (autoscaling) |
| `ecr_repo_name` | `cloudpulse-app` | ECR repository name |

Everything is parameterized — change `terraform.tfvars` to spin up a dev/staging variant without editing module code.

---

## Outputs

After `apply`, key outputs include:

| Output | Used For |
|--------|----------|
| `cluster_name` | `aws eks update-kubeconfig --name <cluster_name>` |
| `ecr_url` | The image registry URL referenced in the app pipeline |
| `vpc_id`, subnet IDs | Reference / verification |

---

## Connecting to the Cluster

Once the infra pipeline completes:

```bash
aws eks update-kubeconfig --region ap-south-1 --name cloudpulse-cluster
kubectl get nodes        # nodes should be Ready
```

---

## Next Step

With the cluster live, the **[cloudpulse-app](https://github.com/rajeshdangi409/cloudpulse-app)** pipeline can build, push, and deploy the application onto this EKS cluster.

---

## State & Locking

- **Remote state:** S3 (`cloudpulse-terraform-state/infra/terraform.tfstate`)
- **Locking:** DynamoDB (`terraform-lock-table`) — prevents concurrent apply corruption
- **Encryption:** state encrypted at rest

> The bootstrap and infra repos use **separate state keys** (`bootstrap/` vs `infra/`) so they never interfere with each other.

---

## Cleanup

Always destroy infra via the **destroy pipeline** (so state stays consistent):

```
Jenkins → cloudpulse-infra-destroy → Build → review destroy plan → confirm
```

> ⚠️ EKS costs ~$0.10/hr and the NAT Gateway ~$0.045/hr. **Destroy promptly after demos.**
