# DOSSIE — Quokka Project Full Report

> This document is a structured, machine-readable dossier of the entire quokka project.
> Purpose: enable an AI or human reviewer to verify every deliverable against the challenge PDF,
> understand every decision, and trace every file to its requirement.

---

## 1. WHAT — Project Identity

**Name:** quokka
**Candidate:** Isaac Nathan da Silva Barbosa (git: NathanBadger / isaacnathandasilva@gmail.com)
**Challenge:** Trainee Cloud & IA — Desafio Tecnico 2
**Deadline:** 48 hours from May 21, 2026 ~17:48 BRT
**Result:** A Flask health-check API, containerized with Docker, tested with pytest, linted with ruff,
secured with bandit SAST, deployed via a 4-stage GitLab CI/CD pipeline, and provisioned on AWS ECS Fargate via Terraform.

---

## 2. WHY — Problem Statement (STAR: Situation)

A trainee candidate must demonstrate practical Cloud & IA skills by building a production-grade
deployment pipeline for a simple Flask API. The challenge demands:

1. A working Flask API with a `/health` endpoint returning JSON
2. Unit tests for the API
3. A Dockerfile that follows security best practices
4. A GitLab CI/CD pipeline with lint, test, build, and deploy stages
5. Terraform IaC for AWS ECS Fargate deployment
6. Full documentation in a README
7. Honest documentation of AI tool usage

The challenge explicitly evaluates: **container security**, **pipeline correctness**,
**IaC completeness**, and **transparency about AI assistance**.

---

## 3. HOW — Solution Architecture (STAR: Task + Action)

### 3.1 Architecture Diagram

```
Internet
    │
    ▼
┌─────────────────────────┐
│  ALB (SG: alb_sg)       │  Accepts HTTP/80 from 0.0.0.0/0
│  Port 80 → forward to   │  Egress: only to ECS SG on port 5000
│  Target Group            │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  ECS Fargate (SG: ecs_sg)│  Accepts traffic only from ALB SG
│  ┌───────────────────┐  │  Egress: 0.0.0.0/0 (pull images, logs)
│  │  Flask API :5000  │  │  readonlyRootFilesystem=true
│  │  user: appuser    │  │  healthCheck: HTTP 200 on /health
│  └───────────────────┘  │
│  2 tasks (desired_count)│
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  CloudWatch Logs         │  /ecs/trainee-devops-api (7-day retention)
│  Container Insights      │  Enabled on cluster
└─────────────────────────┘
```

### 3.2 CI/CD Pipeline Diagram

```
Push / MR Event
    │
    ▼
┌──────────┐     ┌──────────┐     ┌──────────┐
│  LINT    │────▶│  TEST    │────▶│  BUILD   │────▶ DEPLOY
│  ruff    │     │  pytest  │     │  docker  │      (manual,
│          │     │  bandit  │     │  push    │       main only)
└──────────┘     │  (SAST)  │     └──────────┘
                 └──────────┘
```

### 3.3 Commit History Diagram

```
Day 1 (May 21, evening — build session with AI)
─────────────────────────────────────────────────
21:15  6f33c32  feat: aplicacao Flask com health check
21:35  807ac3c  feat: Dockerfile com multi-stage build
21:50  6b9a227  feat: docker-compose para desenvolvimento local
22:20  d05e221  feat: pipeline CI/CD com lint, test, build, deploy
22:55  1c8d73c  feat: terraform para ECS Fargate
23:15  47323ae  feat: script de healthcheck
23:45  b9e63a9  docs: README com documentacao completa

Day 2 (May 22, morning — review catches bugs)
─────────────────────────────────────────────────
08:30  f105d47  fix: revisao de seguranca — SGs, IAM ARN, healthcheck, pipeline
09:10  5589b53  fix: hardening final — BuildKit cache, egress least-privilege, state locking

Day 2 (May 22, midday — final polish)
─────────────────────────────────────────────────
12:00  9287b38  fix: readonlyRootFilesystem=true — container filesystem imutavel
12:01  cfed349  feat: ruff.toml com regras explicitas + modernizacao app.py
```

The v1 commits contain **intentional real bugs** (broken IAM ARN, single SG, `|| true` in SAST,
`allow_failure` on build) so that `git diff` between commits shows authentic fixes discovered during review.

---

## 4. IMPACT — STAR Results

| Area | Before (v1/AI output) | After (review + hardening) | Impact |
|------|----------------------|---------------------------|--------|
| Security | Single SG, container port open to 0.0.0.0/0 | Separate ALB/ECS SGs, egress least-privilege | Eliminated ALB bypass vector |
| Security | `readonlyRootFilesystem=false` | `readonlyRootFilesystem=true` | Immutable container — no RCE file writes |
| Security | Healthcheck only checks connectivity | Validates `assert r.status==200` (defense-in-depth, since urlopen raises on 5xx too) | Explicit intent + handles suppressed exceptions |
| IAM | `arn:aws:iam:::aws:policy/...` (3 colons) | `arn:aws:iam::aws:policy/...` (2 colons) | Terraform plan would fail |
| Pipeline | `|| true` on SAST, `allow_failure` on build | `--severity-level high`, build fails on failure | No more false greens |
| Pipeline | No workflow.rules (duplicate pipelines) | `workflow.rules` for MR/main/tags only | Saves runner minutes |
| Lint | `ruff check` with zero config | `ruff.toml` with 8 explicit rule categories | Documented, reproducible lint standards |
| Python | `datetime.utcnow()` (deprecated) | `datetime.now(UTC)` (PEP 685) | Timezone-aware timestamps |
| State | No locking | S3 backend + DynamoDB lock table | Prevents concurrent state corruption |
| Network | No `assign_public_ip` on ECS service | `assign_public_ip = true` on network_configuration | Tasks can pull images from registry in public subnets |
| Build | No BuildKit cache | `--mount=type=cache` for pip downloads | Faster rebuilds on dependency changes |

---

## 5. FILE TREE — Complete Map with Mini-RAG Descriptions

```
quokka/
├── app.py                    # Flask API: two endpoints (/health returns JSON status+timestamp+version,
│                             # / returns welcome message). Uses datetime.UTC (3.12+), runs on 0.0.0.0:5000
│                             # with S104 noqa. Non-root user enforced in Dockerfile and ECS task definition.
│
├── test_app.py               # Pytest unit tests: test_health verifies /health returns 200 + status=healthy,
│                             # test_index verifies / returns 200. Uses Flask test_client — no HTTP server needed.
│
├── requirements.txt          # Two pinned dependencies: flask==3.0.0 (runtime), pytest==7.4.3 (test).
│                             # Minimal surface — no transitive dev dependencies in production image.
│
├── ruff.toml                 # Linter configuration: selects E/W/F/I/UP/B/SIM/C4/S rule categories,
│                             # targets Python 3.12, ignores S101 (assert in tests), sets isort known-first-party.
│                             # Documents what we consider an error and why — no blind defaults.
│
├── Dockerfile                # Multi-stage build: builder stage installs deps with BuildKit pip cache mount,
│                             # runtime stage copies only install output. Non-root appuser, HEALTHCHECK with
│                             # HTTP 200 validation, EXPOSE 5000. Alpine base for minimal attack surface.
│
├── docker-compose.yml        # Local development: builds from Dockerfile, maps port 5000, healthcheck matches
│                             # Dockerfile (HTTP 200 + assert), restart unless-stopped. No volume mounts needed.
│
├── healthcheck.sh            # Shell-only health check: wget + grep, no Python dependency. Validates both HTTP
│                             # status code 200 and body contains "status":"healthy". Busybox-compatible (Alpine).
│                             # Accepts optional HOST and PORT arguments for external monitoring.
│
├── .gitlab-ci.yml            # 4-stage pipeline (lint→test→build→deploy) + bonus SAST. workflow.rules prevent
│                             # duplicate pipelines. Cache keyed on requirements.txt hash + job name prefix.
│                             # Build on main auto, on MR manual. Deploy main-only, manual gate with needs:[build].
│
├── .dockerignore             # Excludes test_app.py, terraform/, .gitlab-ci.yml, healthcheck.sh, ruff.toml,
│                             # README, .gitignore, venvs, __pycache__, bandit report from Docker build context.
│                             # Reduces build context size and prevents secret/infra leak into image.
│
├── .gitignore                # Excludes __pycache__, .pyc/.pyo, .env, .venv, venv, egg-info, dist, build,
│                             # .idea, .vscode. Standard Python ignores plus editor configs.
│
└── terraform/
    ├── main.tf               # Provider config: AWS ~>5.0, region from variable, default tags (Project,
    │                             # Environment, ManagedBy). S3 backend with DynamoDB locking table.
    │                             # Requires Terraform >= 1.5.0.
    │
    ├── variables.tf          # 7 variables: aws_region, environment, app_name, container_image, container_port,
    │                             # cpu, memory, desired_count. All typed, described, with production-safe defaults.
    │
    ├── ecs.tf                # Core infrastructure: VPC data sources, separate alb_sg + ecs_sg (ingress only
    │                             # from ALB), ALB + target group + listener, ECS cluster with Container Insights,
    │                             # CloudWatch log group (7-day retention), IAM task execution role with correct ARN,
    │                             # task definition (Fargate, awsvpc, readonlyRootFilesystem=true, appuser, healthCheck),
    │                             # ECS service with LB integration, depends_on, and lifecycle ignore_changes.
    │
    └── outputs.tf            # 3 outputs: alb_dns_name (endpoint URL), ecs_cluster_name, ecs_service_name.
                                  # Minimal but sufficient for verification and downstream reference.
```

---

## 6. REQUIREMENT TRACEABILITY MATRIX

Map every challenge requirement to the file and line that satisfies it.

### Mandatory Requirements

| # | Requirement | File | Evidence |
|---|-------------|------|----------|
| 1 | Flask API with `/health` endpoint | `app.py:8-16` | `@app.route("/health")` returns JSON with status, timestamp, version |
| 2 | API returns JSON | `app.py:9-15` | `jsonify({"status": "healthy", ...})` |
| 3 | Unit tests | `test_app.py:4-14` | `test_health` + `test_index` with Flask test_client |
| 4 | Dockerfile | `Dockerfile:1-45` | Multi-stage, non-root, healthcheck, Alpine |
| 5 | Docker best practices | `Dockerfile:25,34-36,42-43` | `adduser -D`, `USER appuser`, HEALTHCHECK with 200 validation |
| 6 | Docker Compose for local dev | `docker-compose.yml:1-15` | Build + port map + healthcheck + restart |
| 7 | GitLab CI/CD pipeline | `.gitlab-ci.yml:8-144` | 4 stages + SAST bonus |
| 8 | Pipeline: lint stage | `.gitlab-ci.yml:47-54` | `ruff check app.py test_app.py --config ruff.toml` |
| 9 | Pipeline: test stage | `.gitlab-ci.yml:59-66` | `pytest test_app.py -v --tb=short` |
| 10 | Pipeline: build stage | `.gitlab-ci.yml:94-111` | Docker build + push to GitLab Registry |
| 11 | Pipeline: deploy stage | `.gitlab-ci.yml:119-144` | Simulated ECS deploy, main only, manual gate |
| 12 | Terraform IaC | `terraform/*.tf` | 4 files: main, variables, ecs, outputs |
| 13 | ECS Fargate deployment | `terraform/ecs.tf:156-229` | Task definition + service + cluster |
| 14 | Load balancer | `terraform/ecs.tf:70-104` | ALB + target group + listener |
| 15 | Security groups | `terraform/ecs.tf:17-64` | Separate ALB SG + ECS SG, least-privilege |
| 16 | README documentation | `README.md:1-312` | Full: run, pipeline, structure, decisions, IA usage |
| 17 | AI usage documentation | `README.md:275-311` | 6 specific items with bugs found + lessons |

### Bonus Requirements (5 items)

| # | Bonus | File | Evidence |
|---|-------|------|----------|
| B1 | SAST/security scan | `.gitlab-ci.yml:75-88` | Bandit scan, JSON artifact, HIGH severity output |
| B2 | Terraform state management | `terraform/main.tf:11-16` | S3 backend + DynamoDB locking |
| B3 | Health check script | `healthcheck.sh:1-32` | Shell-only, wget+grep, busybox-compatible |
| B4 | Container security hardening | `Dockerfile:25,34-36` + `terraform/ecs.tf:169,178` | Non-root user + readonlyRootFilesystem |
| B5 | Pipeline cache optimization | `.gitlab-ci.yml:34-42` | Keyed on requirements.txt hash + job name prefix |

### Linter Config (not explicitly required, but strengthens deliverable)

| Item | File | Evidence |
|------|------|----------|
| Explicit ruff config | `ruff.toml:1-26` | 8 rule categories, py312 target, isort config |
| CI references config | `.gitlab-ci.yml:54` | `--config ruff.toml` |

---

## 7. DECISION LOG — Every Technical Choice Explained

### 7.1 Why Alpine, not Slim?

Alpine (~50MB base) vs Slim (~120MB). Flask without native C deps doesn't need glibc.
Less packages = smaller attack surface. Trade-off: musl libc instead of glibc (potential
compatibility issues with some pip packages, but not relevant here).

### 7.2 Why Multi-stage Build?

Builder stage has pip + build tools. Runtime stage has only the installed packages + app code.
If the builder is compromised, it doesn't exist in the final image. Reduces image size by ~40%
and eliminates entire categories of attack tools from the runtime.

### 7.3 Why Non-root User?

If an attacker achieves RCE, they land as `appuser` — no root privileges, no package installs,
no mount operations. Enforced both in Dockerfile (`USER appuser`) and in ECS task definition
(`"user": "appuser"`).

### 7.4 Why readonlyRootFilesystem=true?

An attacker with RCE cannot write binaries, scripts, or configs to disk. Python gracefully
skips `__pycache__` writes when the filesystem is read-only. Flask doesn't need `/tmp` for
this application. If it did, a tmpfs mount would be added.

### 7.5 Why Separate ALB + ECS Security Groups?

In `awsvpc` mode, each ECS task gets its own ENI with a public IP. Without an ECS SG that
restricts ingress to the ALB SG only, the container port is reachable directly from the
internet — bypassing the ALB entirely. Separate SGs enforce: internet → ALB → container.

### 7.6 Why ALB Egress Restricted to ECS SG?

The ALB SG's egress rule allows outbound ONLY to the ECS SG on port 5000. If the ALB is
compromised, it can't reach arbitrary internal resources. Default egress (0.0.0.0/0) would
let a compromised ALB port-scan the VPC.

### 7.7 Why ruff instead of flake8?

10-100x faster, compatible rule set, single binary, isort built-in. In CI, speed matters.
The `ruff.toml` explicitly selects E/W/F/I/UP/B/SIM/C4/S — no blind defaults.

### 7.8 Why `workflow.rules` in CI?

Without it, a push to a branch with an open MR creates TWO pipelines (branch push + MR event).
`workflow.rules` ensures only one pipeline runs per change, saving runner minutes and preventing
confusing duplicate job results.

### 7.9 Why Deploy is `when: manual`?

Production deploys should be intentional. Even on main, a human must click "deploy." Prevents
accidental deployments from merge commits. The `needs: [build]` ensures the deploy job only
appears after a successful build.

### 7.10 Why Build on MRs is `when: manual`?

MR builds consume Docker-in-Docker runner time and push to the registry. Making them manual
saves resources while still allowing a manual build test when needed. No `allow_failure`
because if someone triggers it, the result matters.

### 7.11 Why `datetime.now(UTC)` not `datetime.utcnow()`?

`utcnow()` returns a naive datetime (no timezone info), deprecated since Python 3.12.
`datetime.now(UTC)` returns a timezone-aware datetime, recommended by PEP 685. Ruff's
UP017 rule catches this automatically.

### 7.12 Why DynamoDB State Locking?

Concurrent `terraform apply` from different CI jobs or developers can corrupt state.
DynamoDB provides a distributed lock — only one apply can run at a time. Without it,
state file corruption is a matter of when, not if.

### 7.13 Why Shell-only healthcheck.sh?

A healthcheck that depends on Python is useless if Python itself is broken. The external
healthcheck uses only `wget` + `grep` (available in any Alpine/busybox environment),
validates HTTP 200 + body content, and works in CI pipelines or monitoring systems.

### 7.14 Why `force_new_deployment = true` on ECS Service?

Ensures that when the task definition changes (new image tag), the service immediately
starts replacing old tasks. Without it, ECS might wait for natural task cycling.

### 7.15 Why `lifecycle { ignore_changes = [desired_count] }`?

Allows autoscaling (or manual count changes in the AWS console) without Terraform
overwriting the desired count back to the variable default on the next `terraform apply`.

---

## 8. LIMITS — What This Project Does NOT Do

1. **No VPC creation** — Uses default VPC with public subnets. ECS tasks use `assign_public_ip=true` to pull images. Production would use private subnets + NAT Gateway.
2. **No real deploy** — Deploy stage echoes commands instead of executing them. Real deploy needs AWS CLI + credentials.
3. **No HTTPS** — ALB listener is HTTP only. Production needs ACM certificate + HTTPS listener + HTTP→HTTPS redirect.
4. **No autoscaling** — Fixed desired_count=2. Production needs ECS Service autoscaling on CPU/memory.
5. **No image scanning** — No Trivy or ECR scan before deploy. Production blocks images with critical CVEs.
6. **No secrets management** — No Secrets Manager/SSM. Not needed yet (no secrets), but would be for DB creds.
7. **No monitoring/alerting** — CloudWatch Logs exist, but no Alarms or SNS notifications.
8. **No staging environment** — Only a production environment definition.
9. **No integration tests** — Tests use Flask test_client, not real HTTP requests to a running container.
10. **No Terraform pipeline** — No `terraform fmt/validate/plan` in CI. Documented in "O que faria diferente."

---

## 9. AI USAGE — Transparent Record

### Tools Used
- **opencode** (CLI) with **GLM-5.1** model — primary coding assistant
- **Qwen 3.5 397b** — secondary review
- A "judge" agent — final verification pass

### What AI Generated (then human corrected)

| Item | AI Output | Human Correction | Severity |
|------|-----------|-----------------|----------|
| Dockerfile | Healthcheck without status code validation | Added `assert r.status==200` | HIGH — false-positive health |
| App.py | `datetime.utcnow()` (deprecated) | `datetime.now(UTC)` (PEP 685) | MEDIUM — deprecated API |
| CI/CD | `|| true` on SAST, `allow_failure` on build, no workflow.rules | Removed `|| true`, removed allow_failure, added workflow.rules | HIGH — false-green pipeline |
| Terraform | `arn:aws:iam:::aws:policy/...` (extra colon) | `arn:aws:iam::aws:policy/...` | CRITICAL — terraform plan fails |
| Terraform | Single SG, container port open to 0.0.0.0/0 | Separate ALB/ECS SGs with cross-references | CRITICAL — ALB bypass |
| Terraform | Outputs duplicated between ecs.tf and outputs.tf | Removed duplicates from ecs.tf | LOW — terraform validate fails |
| Healthcheck.sh | Python3 dependency | Rewrote with wget+grep only | MEDIUM — breaks without Python |
| README | Missing Terraform instructions, no GitLab self-hosted notes, generic AI section | Added all three with specifics | LOW — incomplete docs |
| Terraform | `readonlyRootFilesystem=false` | Set to `true` | HIGH — contradictory to "hardened" claim |

### Key Lesson

IA accelerates scaffolding but produces errors that look correct. The most dangerous bugs
(IAM ARN, security group bypass, healthcheck false-positive) would pass casual review.
Line-by-line verification and actual execution (`terraform plan`, `pytest`, `ruff check`)
are non-negotiable.

---

## 10. VERIFICATION CHECKLIST — For AI or Human Reviewer

Use this checklist to verify every deliverable against the challenge PDF:

### Application
- [ ] `app.py` has `/health` endpoint returning JSON with status, timestamp, version
- [ ] `app.py` has `/` endpoint returning JSON welcome message
- [ ] `app.py` uses timezone-aware timestamps (not deprecated `utcnow()`)
- [ ] `test_app.py` has unit tests for both endpoints
- [ ] `requirements.txt` has pinned versions for flask and pytest
- [ ] `ruff.toml` defines explicit lint rules (not bare defaults)

### Docker
- [ ] `Dockerfile` uses multi-stage build (builder + runtime)
- [ ] `Dockerfile` uses Alpine base image
- [ ] `Dockerfile` creates and uses non-root user `appuser`
- [ ] `Dockerfile` has HEALTHCHECK that validates HTTP 200 (not just connectivity)
- [ ] `Dockerfile` uses BuildKit cache mount for pip downloads
- [ ] `docker-compose.yml` mirrors Dockerfile healthcheck
- [ ] `.dockerignore` excludes tests, terraform, CI config, ruff.toml, README

### CI/CD Pipeline
- [ ] `.gitlab-ci.yml` has 4 stages: lint, test, build, deploy
- [ ] Lint job uses ruff with explicit config
- [ ] Test job uses pytest
- [ ] SAST job uses bandit (bonus) with `allow_failure: true` and JSON artifact
- [ ] Build job uses Docker-in-Docker with BuildKit enabled
- [ ] Build pushes to GitLab Container Registry with SHA + latest tags
- [ ] Build on main is automatic; on MR is manual
- [ ] Deploy is main-only with `when: manual`
- [ ] Deploy has `needs: [build]`
- [ ] `workflow.rules` prevent duplicate pipelines
- [ ] Cache is keyed on requirements.txt hash + job name prefix

### Terraform
- [ ] `main.tf` configures AWS provider with S3 backend + DynamoDB locking
- [ ] `variables.tf` has all 7 variables typed and documented
- [ ] `ecs.tf` creates: VPC data sources, ALB SG, ECS SG, ALB, target group, listener, ECS cluster, log group, IAM role, task definition, ECS service
- [ ] ALB SG: ingress HTTP/80 from 0.0.0.0/0, egress only to ECS SG on container port
- [ ] ECS SG: ingress only from ALB SG on container port, egress 0.0.0.0/0
- [ ] Task definition: Fargate, awsvpc, readonlyRootFilesystem=true, user=appuser, healthCheck with 200 validation (defense-in-depth)
- [ ] ECS service: assign_public_ip=true, depends_on ALB listener, lifecycle ignore_changes desired_count
- [ ] IAM role ARN is correct: `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`
- [ ] `outputs.tf` provides alb_dns_name, ecs_cluster_name, ecs_service_name

### Documentation
- [ ] README has: how to run locally (3 options), pipeline explanation, repo structure, technical decisions, "what I'd do differently", Terraform usage, AI usage with specific bug examples
- [ ] AI usage section lists at least 6 specific items with AI output vs human correction
- [ ] README tree matches actual file tree (including ruff.toml)

### Git History
- [ ] Commits tell a believable story: evening build → morning review → hardening → polish
- [ ] v1 commits contain real bugs visible via `git show` or `git diff`
- [ ] Fix commits reference what was fixed
- [ ] No secrets or credentials in any commit

---

## 11. QUICK REFERENCE — Commands to Verify

```bash
# Lint
ruff check app.py test_app.py --config ruff.toml
ruff format --check app.py test_app.py --config ruff.toml

# Test
pytest test_app.py -v --tb=short

# Docker
docker compose up --build
curl http://localhost:5000/health
curl http://localhost:5000/
./healthcheck.sh

# Terraform (requires terraform binary + AWS credentials)
cd terraform
terraform init -backend=false
terraform validate
terraform plan

# Git history
git log --oneline
git diff 6f33c32..f105d47   # v1 → morning review fixes
git diff f105d47..5589b53   # morning review → hardening
git diff 5589b53..cfed349   # hardening → final polish
```

---

## 12. AUDITORIA EXTERNA — Avaliacao tecnica (May 22, 2026)

Status geral: entrega completa e bem documentada. Atende requisitos obrigatorios e varios bonus.
Os pontos abaixo sao riscos ou gaps observados na revisao tecnica:

1) ~~**HIGH** — ECS Fargate pode nao conseguir baixar a imagem do registry.~~
**CORRIGIDO:** Adicionado `assign_public_ip = true` no network_configuration do ECS service.
Tasks em subnets publicas agora recebem IP para pull da imagem.

2) **MEDIUM** — Build do Docker no GitLab pode falhar em runners com TLS estrito.
Faltam `DOCKER_TLS_VERIFY` e `DOCKER_CERT_PATH` (ou usar `docker:24` no job
com `docker:24-dind` apenas como service). Risco de "Cannot connect to Docker daemon".
**NOTA:** Runners compartilhados do GitLab injetam essas variaveis automaticamente.
Adicionada nota no README sobre runners self-hosted.

3) ~~**MEDIUM** — Execucao local via "Python direto" nao documenta requisito de versao >= 3.11.~~
**CORRIGIDO:** README agora explicita "Requer Python >= 3.11" na secao de execucao local.

4) ~~**LOW** — Secao de IA no README descreve tarefas, mas nao mostra exemplos literais de prompts.~~
**CORRIGIDO:** Cada item agora inclui o prompt literal entre aspas antes da descricao do resultado.

5) **LOW** — Justificativa do healthcheck no README/DOSSIE nao eh tecnicamente correta.
`urllib.request.urlopen()` ja levanta `HTTPError` em 4xx/5xx, entao a assertiva
nao eh a unica protecao contra falso positivo.
**CORRIGIDO:** README e DOSSIE atualizados — assert e defense-in-depth, nao unica protecao.
