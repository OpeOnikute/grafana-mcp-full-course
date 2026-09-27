# Grafana MCP — Full Course

Companion code for the course. You will run Grafana MCP locally with Docker, deploy a Prometheus, Loki, and Grafana stack on Amazon EKS with Terraform, then run the same MCP server on ECS Fargate and on EKS and connect it to an AI coding assistant.

Chapters 1 and 2 are conceptual. The files in this repo are the finished result of Chapters 3–5. The lectures build those files step by step. Use the videos while you are following along, and use this repository when you want the complete environment.

## Prerequisites

From lecture 1.4. You should already be comfortable with the command line, Docker, Kubernetes (`kubectl logs`, Deployments, Services), Grafana, Prometheus, AWS (account, IAM, VPC), and Git.

Install:

- Docker
- Terraform >= 1.5
- AWS CLI v2, authenticated
- `kubectl` and `helm`
- `git`
- An MCP-capable editor (Cursor, Claude Code, Devin Desktop, or OpenCode)

You also need a Grafana Cloud account for Chapter 3, and an AWS account with permission to create VPC, EKS, ECS, load balancer, Secrets Manager, CloudWatch Logs, and IAM resources.

## Repository layout

| Path | Lectures | What it is |
|------|----------|------------|
| `docker-compose.yml` | 3.1–3.2 | Local Grafana and Grafana MCP |
| `terraform/main.tf` | 4.2, 4.3 | VPC and EKS |
| `terraform/monitoring.tf` | 4.4 | kube-prometheus-stack and Loki |
| `terraform/demo_app.tf` | 4.5 | Demo app and ServiceMonitor |
| `terraform/mcp-ecs-secrets.tf` | 5.2, 5.4 | Secrets Manager secret for the Grafana token |
| `terraform/mcs-ecs-iam.tf` | 5.2, 5.4 | ECS task and execution roles |
| `terraform/mcs-ecs-task.tf` | 5.2, 5.3 | Fargate task definition and service |
| `terraform/mcp-ecs-network.tf` | 5.3 | ALB, security groups, VPC endpoints |
| `terraform/mcp-ecs-dns.tf` | 5.3 | Commented Route 53 / ACM example |
| `terraform/mcp-eks.tf` | 5.5 | `grafana-mcp` Helm chart on EKS |
| `terraform/providers.tf` | 4.1, 4.3 | AWS, Kubernetes, and Helm providers |
| `terraform/variables.tf` | 4–5 | Inputs |
| `terraform/outputs.tf` | 4–5 | VPC, cluster, Grafana, and MCP URLs |

`.env` and `.env.cloud` are gitignored. Create them locally. Never commit a service account token.

## Local Grafana MCP (Chapter 3)

Lecture 3.1 builds `docker-compose.yml`. This copy already includes the read-only flag from later in that lecture (`--disable-write`). Host port **8005** maps to container port 8000.

1. Start the stack once so Grafana is up:

```bash
docker compose up -d grafana
```

2. Open `http://localhost:3000` and sign in as `admin` / `admin12345`.

3. Create a service account (lecture 3.2): **Administration → Users and access → Service accounts**. Name it `mcp-local`, give it the **Editor** role, add a token, and copy the token.

4. Create `.env` next to `docker-compose.yml`:

```bash
GRAFANA_URL=http://grafana:3000
GRAFANA_SERVICE_ACCOUNT_TOKEN=<paste-your-token-here>
```

`GRAFANA_URL` uses the Compose service name `grafana`, because the MCP container shares the Compose network.

5. Start the MCP server and check it:

```bash
docker compose up -d
curl http://localhost:8005/healthz
```

A healthy server returns `ok`.

This Compose file always loads `.env`. Lecture 3.4 keeps Grafana Cloud in a separate `.env.cloud` (also gitignored) and points a Cloud-only Compose service at `https://yourname.grafana.net`. Follow that lecture for the Cloud lab. Keep the local token in `.env`.

Chapter 6 registers Grafana MCP with Claude Code, Cursor, Devin Desktop, and OpenCode. Those lectures use either a local `stdio` Docker command or the remote endpoint from Chapter 5. Client config lives in the editor, not in this repo.

## AWS stack (Chapters 4 and 5)

This Terraform project is one state file for the whole stack: VPC, EKS, Prometheus, Loki, Grafana, the demo app, MCP on ECS Fargate, and MCP on EKS.

**Cost.** EKS, the NAT gateway, the managed node group (`t3.large`, two nodes), the Grafana load balancer, the MCP ALB, Fargate, and the interface VPC endpoints are not free-tier. Run `terraform destroy` when you finish a session.

Defaults live in `terraform/variables.tf`: region `us-east-1`, project name `grafana-mcp`, Kubernetes `1.34`. `deploy_monitoring` defaults to `true`, so Prometheus, Loki, and Grafana are included. The demo app and both MCP paths are always in the configuration.

`mcp-ecs-dns.tf` and the HTTPS listener are commented out. The course hits the ALB hostname over HTTP.

### Apply

The Kubernetes and Helm providers read the EKS endpoint, so the cluster has to exist before the rest of the config is planned. Lectures 4.2 and 4.3 target the VPC and the cluster first. Lecture 5.2 creates the Secrets Manager secret and writes the token before the ECS task starts.

```bash
cd terraform
export AWS_DEFAULT_REGION=us-east-1
export TF_PLUGIN_TIMEOUT=120   # Apple Silicon, if plan times out
terraform init

terraform apply -target=module.vpc
terraform apply -target=module.eks

aws eks update-kubeconfig --name grafana-mcp --region us-east-1

terraform apply -target=aws_secretsmanager_secret.grafana_sa_token

aws secretsmanager put-secret-value \
  --secret-id grafana-mcp/grafana-sa-token \
  --secret-string '<your-grafana-service-account-token>' \
  --region us-east-1

export TF_VAR_mcp_grafana_token='<your-grafana-service-account-token>'
terraform apply
```

`TF_VAR_mcp_grafana_token` is required. The EKS Helm release (`mcp-eks.tf`) passes it as `grafana.apiKey`. The ECS task reads the same token from Secrets Manager, not from that variable.

Leave `mcp_grafana_url` empty. The ECS task then uses the Grafana load balancer from Chapter 4 (`terraform output grafana_url`). Set `TF_VAR_mcp_grafana_url` only when ECS should talk to a different Grafana, such as Grafana Cloud.

Set a real Grafana admin password before apply if you do not want the default:

```bash
export TF_VAR_grafana_admin_password='something-strong'
```

### Check the stack

```bash
terraform output grafana_url
curl "$(terraform output -raw mcp_url)/healthz"

kubectl get pods -n monitoring
kubectl get pods -n demo
kubectl get pods -n mcp
kubectl port-forward -n mcp svc/grafana-mcp 8000:8000
```

With the port-forward running, `curl http://localhost:8000/healthz` checks the EKS server. The ECS server is the ALB URL from `mcp_url`.

Both servers run streamable HTTP, listen on port 8000, and pass `--disable-write`. The EKS chart talks to Grafana at `http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local`.

### Destroy

```bash
cd terraform
terraform destroy
```

EKS and the networking resources keep billing until they are removed.

## What each chapter uses

| Chapter | Lectures | In this repo |
|---------|----------|----------------|
| 1 — Welcome | 1.1–1.4 | Prerequisites above |
| 2 — MCP fundamentals | 2.1–2.5 | No code. Clients, servers, transports, and security |
| 3 — Local install | 3.1–3.5 | `docker-compose.yml` |
| 4 — Terraform on AWS | 4.1–4.5 | `terraform/main.tf`, `monitoring.tf`, `demo_app.tf` |
| 5 — Grafana MCP on AWS | 5.1–5.7 | `terraform/mcp-ecs-*.tf`, `mcs-ecs-*.tf`, `mcp-eks.tf` |
| 6 — MCP clients | 6.1–6.4 | Point Claude Code, Cursor, Devin Desktop, or OpenCode at the local server or the ALB |
| 7 — Wrap-up | 7.1–7.2 | Recap. Destroy the AWS environment when you are done |

## Further reading

- [Grafana MCP documentation](https://grafana.com/docs/grafana/latest/developer-resources/mcp/)
- [grafana/mcp-grafana](https://github.com/grafana/mcp-grafana)
- [grafana-mcp Helm chart](https://github.com/grafana-community/helm-charts/tree/main/charts/grafana-mcp)
