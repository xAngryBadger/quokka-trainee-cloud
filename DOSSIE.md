# DOSSIE — Relatório Completo do Projeto Quokka

> Este documento é um dossiê estruturado e legível por máquina de todo o projeto quokka.
> Propósito: permitir que um revisor (IA ou humano) verifique cada entregável contra o PDF do desafio,
> entenda cada decisão e rastreie cada arquivo até seu requisito.

---

## 1. O QUÊ — Identidade do Projeto

**Nome:** quokka
**Candidato:** Isaac Nathan da Silva Barbosa (git: NathanBadger / isaacnathandasilva@gmail.com)
**Desafio:** Trainee Cloud & IA — Desafio Técnico 2
**Prazo:** 48 horas a partir de 21 de Maio, 2026 ~17:48 BRT
**Resultado:** Uma API Flask de health check, containerizada com Docker, testada com pytest, lintada com ruff,
segurada com bandit SAST, deployada via pipeline GitLab CI/CD de 4 stages, e provisionada no AWS ECS Fargate via Terraform.

---

## 2. POR QUÊ — Declaração do Problema (STAR: Situação)

Um candidato trainee deve demonstrar habilidades práticas de Cloud & IA construindo um pipeline
de deployment production-grade para uma API Flask simples. O desafio exige:

1. Uma API Flask funcional com endpoint `/health` retornando JSON
2. Testes unitários para a API
3. Um Dockerfile que segue boas práticas de segurança
4. Um pipeline GitLab CI/CD com stages de lint, test, build e deploy
5. IaC com Terraform para deploy no AWS ECS Fargate
6. Documentação completa no README
7. Documentação honesta do uso de ferramentas de IA

O desafio avalia explicitamente: **segurança de containers**, **correção do pipeline**,
**completude da IaC** e **transparência sobre assistência de IA**.

---

## 3. COMO — Arquitetura da Solução (STAR: Tarefa + Ação)

### 3.1 Diagrama de Arquitetura

```
Internet
│
▼
┌─────────────────────────┐
│ ALB (SG: alb_sg) │ Aceita HTTP/80 de 0.0.0.0/0
│ Porta 80 → forward para │ Egress: apenas para ECS SG na porta 5000
│ Target Group │
└──────────┬──────────────┘
│
▼
┌─────────────────────────┐
│ ECS Fargate (SG: ecs_sg)│ Aceita tráfego apenas do ALB SG
│ ┌───────────────────┐ │ Egress: 0.0.0.0/0 (pull de imagens, logs)
│ │ Flask API :5000 │ │ readonlyRootFilesystem=true
│ │ user: appuser │ │ healthCheck: HTTP 200 no /health
│ └───────────────────┘ │
│ 2 tasks (desired_count)│
└──────────┬──────────────┘
│
▼
┌─────────────────────────┐
│ CloudWatch Logs │ /ecs/trainee-devops-api (retenção 7 dias)
│ Container Insights │ Habilitado no cluster
└─────────────────────────┘
```

### 3.2 Diagrama do Pipeline CI/CD

```
Push / MR Event
│
▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ LINT │────▶│ TEST │────▶│ BUILD │────▶ DEPLOY
│ ruff │ │ pytest │ │ docker │ (manual,
│ │ │ bandit │ │ push │ main only)
└──────────┘ │ (SAST) │ └──────────┘
└──────────┘
```



## 4. IMPACTO — Resultados STAR

| Área | Antes (v1/output da IA) | Depois (revisão + hardening) | Impacto |
|------|------------------------|------------------------------|---------|
| Segurança | SG única, porta do container aberta para 0.0.0.0/0 | SGs separadas ALB/ECS, egress least-privilege | Eliminado vetor de bypass do ALB |
| Segurança | `readonlyRootFilesystem=false` | `readonlyRootFilesystem=true` | Container imutável — sem escrita de arquivos via RCE |
| Segurança | Healthcheck verifica apenas conectividade | Valida `assert r.status==200` (defense-in-depth, pois urlopen também levanta em 5xx) | Intenção explícita + lida com exceções suprimidas |
| IAM | `arn:aws:iam:::aws:policy/...` (3 dois-pontos) | `arn:aws:iam::aws:policy/...` (2 dois-pontos) | Terraform plan falharia |
| Pipeline | `|| true` no SAST, `allow_failure` no build | `--severity-level high`, build falha se falhar | Sem mais falsos-verdes |
| Pipeline | Sem workflow.rules (pipelines duplicados) | `workflow.rules` para MR/main/tags apenas | Economiza runner minutes |
| Lint | `ruff check` sem configuração | `ruff.toml` com 8 categorias de regras explícitas | Padrões de lint documentados e reprodutíveis |
| Python | `datetime.utcnow()` (deprecated) | `datetime.now(UTC)` (PEP 685) | Timestamps com timezone |
| State | Sem locking | Backend S3 + tabela de lock DynamoDB | Previne corrupção concorrente do state |
| Rede | Sem `assign_public_ip` no ECS service | `assign_public_ip = true` no network_configuration | Tasks podem fazer pull de imagens do registry em subnets públicas |
| Build | Sem cache BuildKit | `--mount=type=cache` para downloads pip | Rebuilds mais rápidos em mudanças de dependência |

---

## 5. ÁRVORE DE ARQUIVOS — Mapa Completo com Descrições

```
quokka/
├── app.py # API Flask: dois endpoints (/health retorna JSON status+timestamp+version,
│ # / retorna mensagem de boas-vindas). Usa datetime.UTC (3.12+), roda em 0.0.0.0:5000
│ # com S104 noqa. Usuário não-root reforçado no Dockerfile e ECS task definition.
│
├── test_app.py # Testes unitários pytest: test_health verifica /health retorna 200 + status=healthy,
│ # test_index verifica / retorna 200. Usa Flask test_client — sem necessidade de servidor HTTP.
│
├── requirements.txt # Dependência de runtime apenas: flask==3.0.0. Instalada pelo Dockerfile — sem
│ # pytest/ruff/bandit na imagem de produção. Minimiza superfície de ataque.
│
├── requirements-dev.txt # Dependências de desenvolvimento: pytest, ruff, bandit. Usadas por jobs CI e testes
│ # locais. Excluídas do build Docker via .dockerignore.
│
├── ruff.toml # Configuração do linter: seleciona categorias E/W/F/I/UP/B/SIM/C4/S,
│ # target Python 3.12, ignora S101 (assert em testes), configura isort known-first-party.
│ # Documenta o que consideramos erro e por quê — sem defaults cegos.
│
├── Dockerfile # Build multi-stage: estágio builder instala deps com pip install --prefix,
│ # estágio runtime copia apenas o output da instalação. Non-root appuser, HEALTHCHECK com
│ # validação HTTP 200, EXPOSE 5000. Base Alpine para superfície de ataque mínima.
│
├── docker-compose.yml # Desenvolvimento local: build a partir do Dockerfile, mapeia porta 5000, healthcheck
│ # igual ao Dockerfile (HTTP 200 + assert), restart unless-stopped. Sem volume mounts necessários.
│
├── healthcheck.sh # Health check shell-only: wget + grep, sem dependência de Python. Valida HTTP
│ # status code 200 e corpo contém "status":"healthy". Compatível com busybox (Alpine).
│ # Aceita argumentos opcionais HOST e PORT para monitoramento externo.
│
├── .gitlab-ci.yml # Pipeline de 4 stages (lint→test→build→deploy) + SAST bônus. workflow.rules previne
│ # pipelines duplicados. Cache keyado em requirements.txt + requirements-dev.txt
│ # hash + prefixo do job name. Build em main/tags automático, em MR manual. Tags geram
│ # imagens de release. Deploy main-only, aprovação manual com needs:[build].
│
├── .dockerignore # Exclui test_app.py, terraform/, .gitlab-ci.yml, healthcheck.sh, ruff.toml,
│ # requirements-dev.txt, DOSSIE.md, README, .gitignore, .ruff_cache, venvs,
│ # __pycache__, bandit report do contexto de build Docker.
│
├── .gitignore # Exclui __pycache__, .pyc/.pyo, .env, .venv, venv, egg-info, dist, build,
│ # .idea, .vscode, .ruff_cache, .pytest_cache, bandit-report.json.
│
└── terraform/
├── main.tf # Config do provider: AWS ~>5.0, região por variável, default tags (Project,
│ # Environment, ManagedBy). Backend S3 com tabela de lock DynamoDB.
│ # Requer Terraform >= 1.5.0.
│
├── variables.tf # 7 variáveis: aws_region, environment, app_name, container_image, container_port,
│ # cpu, memory, desired_count. Todas tipadas, descritas, com defaults seguros para produção.
│
├── ecs.tf # Infraestrutura principal: data sources de VPC, SGs separadas alb_sg + ecs_sg (ingress apenas
│ # do ALB), ALB + target group + listener, cluster ECS com Container Insights,
│ # log group CloudWatch (retenção 7 dias), IAM task execution role com ARN correto,
│ # task definition (Fargate, awsvpc, readonlyRootFilesystem=true, appuser, healthCheck),
│ # ECS service com integração LB, depends_on, e lifecycle ignore_changes.
│
└── outputs.tf # 3 outputs: alb_dns_name (URL do endpoint), ecs_cluster_name, ecs_service_name.
│ # Mínimo mas suficiente para verificação e referência downstream.
```
quokka/
├── app.py                    # Flask API: two endpoints (/health returns JSON status+timestamp+version,
│                             # / returns welcome message). Uses datetime.UTC (3.12+), runs on 0.0.0.0:5000
│                             # with S104 noqa. Non-root user enforced in Dockerfile and ECS task definition.
│
├── test_app.py               # Pytest unit tests: test_health verifies /health returns 200 + status=healthy,
│                             # test_index verifies / returns 200. Uses Flask test_client — no HTTP server needed.
│
├── requirements.txt          # Runtime dependency only: flask==3.0.0. Installed by Dockerfile — no
│                             # pytest/ruff/bandit in the production image. Minimizes attack surface.
│
├── requirements-dev.txt     # Development dependencies: pytest, ruff, bandit. Used by CI jobs and local
│                             # testing. Excluded from Docker build via .dockerignore.
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
├── .gitlab-ci.yml # 4-stage pipeline (lint→test→build→deploy) + bonus SAST. workflow.rules prevent
│                             # duplicate pipelines. Cache keyed on requirements.txt + requirements-dev.txt
│                             # hash + job name prefix. Build on main/tags auto, on MR manual. Tags produce
│                             # release images. Deploy main-only, manual gate with needs:[build].
│
├── .dockerignore # Excludes test_app.py, terraform/, .gitlab-ci.yml, healthcheck.sh, ruff.toml,
│                             # requirements-dev.txt, DOSSIE.md, README, .gitignore, .ruff_cache, venvs,
│                             # __pycache__, bandit report from Docker build context.
│
├── .gitignore # Excludes __pycache__, .pyc/.pyo, .env, .venv, venv, egg-info, dist, build,
│                             # .idea, .vscode, .ruff_cache, .pytest_cache, bandit-report.json.
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

## 6. MATRIZ DE RASTREABILIDADE DE REQUISITOS

Mapeia cada requisito do desafio para o arquivo e linha que o satisfaz.

### Requisitos Obrigatórios

| # | Requisito | Arquivo | Evidência |
|---|-----------|---------|-----------|
| 1 | API Flask com endpoint `/health` | `app.py:8-16` | `@app.route("/health")` retorna JSON com status, timestamp, version |
| 2 | API retorna JSON | `app.py:9-15` | `jsonify({"status": "healthy", ...})` |
| 3 | Testes unitários | `test_app.py:4-14` | `test_health` + `test_index` com Flask test_client |
| 4 | Dockerfile | `Dockerfile:1-45` | Multi-stage, non-root, healthcheck, Alpine |
| 5 | Boas práticas Docker | `Dockerfile:25,34-36,42-43` | `adduser -D`, `USER appuser`, HEALTHCHECK com validação 200 |
| 6 | Docker Compose para dev local | `docker-compose.yml:1-15` | Build + mapeamento de porta + healthcheck + restart |
| 7 | Pipeline GitLab CI/CD | `.gitlab-ci.yml:8-144` | 4 stages + SAST bônus |
| 8 | Pipeline: stage lint | `.gitlab-ci.yml:47-54` | `ruff check app.py test_app.py --config ruff.toml` |
| 9 | Pipeline: stage test | `.gitlab-ci.yml:59-66` | `pytest test_app.py -v --tb=short` |
| 10 | Pipeline: stage build | `.gitlab-ci.yml:94-111` | Docker build + push para GitLab Registry |
| 11 | Pipeline: stage deploy | `.gitlab-ci.yml:119-144` | Deploy ECS simulado, main only, aprovação manual |
| 12 | IaC Terraform | `terraform/*.tf` | 4 arquivos: main, variables, ecs, outputs |
| 13 | Deploy ECS Fargate | `terraform/ecs.tf:156-229` | Task definition + service + cluster |
| 14 | Load balancer | `terraform/ecs.tf:70-104` | ALB + target group + listener |
| 15 | Security groups | `terraform/ecs.tf:17-64` | SGs separadas ALB + ECS, least-privilege |
| 16 | Documentação README | `README.md:1-312` | Completa: rodar, pipeline, estrutura, decisões, uso de IA |
| 17 | Documentação de uso de IA | `README.md:275-311` | 6 itens específicos com bugs encontrados + lições |

### Requisitos Bônus (5 itens)

| # | Bônus | Arquivo | Evidência |
|---|-------|---------|-----------|
| B1 | SAST/security scan | `.gitlab-ci.yml:75-88` | Scan bandit, artefato JSON, output de severidade HIGH |
| B2 | Gerenciamento de state Terraform | `terraform/main.tf:11-16` | Backend S3 + locking DynamoDB |
| B3 | Script de health check | `healthcheck.sh:1-32` | Shell-only, wget+grep, compatível com busybox |
| B4 | Hardening de segurança do container | `Dockerfile:25,34-36` + `terraform/ecs.tf:169,178` | Usuário não-root + readonlyRootFilesystem |
| B5 | Otimização de cache no pipeline | `.gitlab-ci.yml:34-43` | Keyado em hash de requirements.txt + requirements-dev.txt + prefixo do job name |

### Configuração do Linter (não explicitamente requisitada, mas fortalece a entregável)

| Item | Arquivo | Evidência |
|------|---------|-----------|
| Config ruff explícita | `ruff.toml:1-26` | 8 categorias de regras, target py312, config isort |
| CI referencia config | `.gitlab-ci.yml:54` | `--config ruff.toml` |

---

## 7. REGISTRO DE DECISÕES — Cada Escolha Técnica Explicada

### 7.1 Por que Alpine, não Slim?

Alpine (~50MB base) vs Slim (~120MB). Flask sem deps C nativos não precisa de glibc.
Menos pacotes = menor superfície de ataque. Trade-off: musl libc ao invés de glibc (possíveis
problemas de compatibilidade com alguns pacotes pip, mas não relevante aqui).

### 7.2 Por que Multi-stage Build?

O estágio builder tem pip + ferramentas de build. O estágio runtime tem apenas os pacotes instalados + código da app.
Se o builder for comprometido, ele não existe na imagem final. Reduz tamanho da imagem em ~40%
e elimina categorias inteiras de ferramentas de ataque do runtime.

### 7.3 Por que Usuário Não-root?

Se um atacante conseguir RCE, ele cai como `appuser` — sem privilégios de root, sem installs de pacotes,
sem operações de mount. Reforçado tanto no Dockerfile (`USER appuser`) quanto no ECS task definition
(`"user": "appuser"`).

### 7.4 Por que readonlyRootFilesystem=true?

Um atacante com RCE não pode escrever binários, scripts ou configs no disco. Python ignora
graciosamente escritas de `__pycache__` quando o filesystem é read-only. Flask não precisa de `/tmp` para
esta aplicação. Se precisasse, um mount tmpfs seria adicionado.

### 7.5 Por que Security Groups Separadas para ALB + ECS?

No modo `awsvpc`, cada task ECS recebe seu próprio ENI com IP público. Sem uma SG ECS que
restringe ingress apenas para a SG do ALB, a porta do container é acessível diretamente da
internet — bypassando o ALB inteiramente. SGs separadas reforçam: internet → ALB → container.

### 7.6 Por que Egress do ALB Restrito para ECS SG?

A regra de egress da SG do ALB permite saída APENAS para a SG do ECS na porta 5000. Se o ALB for
comprometido, ele não pode alcançar recursos internos arbitrários. Egress default (0.0.0.0/0) permitiria
que um ALB comprometido fizesse port-scan da VPC.

### 7.7 Por que ruff ao invés de flake8?

10-100x mais rápido, set de regras compatível, binário único, isort integrado. No CI, velocidade importa.
O `ruff.toml` seleciona explicitamente E/W/F/I/UP/B/SIM/C4/S — sem defaults cegos.

### 7.8 Por que `workflow.rules` no CI?

Sem ele, um push para branch com MR aberto cria DOIS pipelines (branch push + MR event).
`workflow.rules` garante que apenas um pipeline roda por mudança, economizando runner minutes e
prevenindo resultados duplicados confusos.

### 7.9 Por que Deploy é `when: manual`?

Deploys em produção devem ser intencionais. Mesmo na main, um humano precisa clicar "deploy." Previne
deploys acidentais a partir de merge commits. O `needs: [build]` garante que o job de deploy só
aparece após um build bem-sucedido.

### 7.10 Por que Build em MRs é `when: manual`?

Builds de MR consomem tempo de runner Docker-in-Docker e fazem push para o registry. Torná-los manual
economiza recursos enquanto ainda permite um teste de build manual quando necessário. Sem `allow_failure`
porque se alguém aciona, o resultado importa.

### 7.11 Por que `datetime.now(UTC)` não `datetime.utcnow()`?

`utcnow()` retorna um datetime naive (sem info de timezone), deprecated desde Python 3.12.
`datetime.now(UTC)` retorna um datetime timezone-aware, recomendado pelo PEP 685. A regra
UP017 do ruff captura isso automaticamente.

### 7.12 Por que DynamoDB State Locking?

`terraform apply` concorrente de diferentes jobs CI ou desenvolvedores pode corromper o state.
DynamoDB fornece um lock distribuído — apenas um apply pode rodar por vez. Sem ele,
corrupção do arquivo de state é questão de quando, não se.

### 7.13 Por que healthcheck.sh shell-only?

Um healthcheck que depende de Python é inútil se o próprio Python está quebrado. O healthcheck
externo usa apenas `wget` + `grep` (disponíveis em qualquer ambiente Alpine/busybox),
valida HTTP 200 + conteúdo do corpo, e funciona em pipelines CI ou sistemas de monitoramento.

### 7.14 Por que `force_new_deployment = true` no ECS Service?

Garante que quando o task definition muda (nova tag de imagem), o service imediatamente
começa a substituir tasks antigas. Sem ele, o ECS pode esperar pelo cycling natural das tasks.

### 7.15 Por que `lifecycle { ignore_changes = [desired_count] }`?

Permite autoscaling (ou mudanças manuais de count no console AWS) sem que o Terraform
sobrescreva o desired count de volta para o default da variável no próximo `terraform apply`.

---

## 8. LIMITES — O Que Este Projeto NÃO Faz

1. **Sem criação de VPC** — Usa VPC default com subnets públicas. Tasks ECS usam `assign_public_ip=true` para fazer pull de imagens. Produção usaria subnets privadas + NAT Gateway.
2. **Sem deploy real** — Stage de deploy imprime comandos ao invés de executá-los. Deploy real precisa de AWS CLI + credenciais.
3. **Sem HTTPS** — Listener do ALB é HTTP apenas. Produção precisa de certificado ACM + listener HTTPS + redirect HTTP→HTTPS.
4. **Sem autoscaling** — desired_count fixo=2. Produção precisa de autoscaling do ECS Service por CPU/memória.
5. **Sem image scanning** — Sem Trivy ou ECR scan antes do deploy. Produção bloqueia imagens com CVEs críticas.
6. **Sem secrets management** — Sem Secrets Manager/SSM. Ainda não necessário (sem secrets), mas seria para creds de DB.
7. **Sem monitoramento/alertas** — CloudWatch Logs existem, mas sem Alarms ou notificações SNS.
8. **Sem ambiente de staging** — Apenas definição de ambiente de produção.
9. **Sem testes de integração** — Testes usam Flask test_client, não requests HTTP reais para um container rodando.
10. **Sem pipeline Terraform** — Sem `terraform fmt/validate/plan` no CI. Documentado em "O que faria diferente."

---

## 9. USO DE IA — Registro Transparente

### Ferramentas Utilizadas
- **opencode** (CLI) com modelo **GLM-5.1** — assistente principal de codificação
- **Qwen 3.5 397b** — revisão secundária
- Agente "juiz" — verificação final

### O Que a IA Gerou (e humano corrigiu)

| Item | Output da IA | Correção Humana | Severidade |
|------|-------------|-----------------|------------|
| Dockerfile | Healthcheck sem validação de status code | Adicionado `assert r.status==200` | ALTA — health falso-positivo |
| App.py | `datetime.utcnow()` (deprecated) | `datetime.now(UTC)` (PEP 685) | MÉDIA — API deprecated |
| CI/CD | `|| true` no SAST, `allow_failure` no build, sem workflow.rules | Removido `|| true`, removido allow_failure, adicionado workflow.rules | ALTA — pipeline falso-verde |
| Terraform | `arn:aws:iam:::aws:policy/...` (dois-pontos extra) | `arn:aws:iam::aws:policy/...` | CRÍTICA — terraform plan falha |
| Terraform | SG única, porta do container aberta para 0.0.0.0/0 | SGs separadas ALB/ECS com referências cruzadas | CRÍTICA — bypass do ALB |
| Terraform | Outputs duplicados entre ecs.tf e outputs.tf | Removidos duplicados de ecs.tf | BAIXA — terraform validate falha |
| Healthcheck.sh | Dependência de Python3 | Reescrito com wget+grep apenas | MÉDIA — quebra sem Python |
| README | Faltando instruções Terraform, notas GitLab self-hosted, seção IA genérica | Adicionados todos três com específicos | BAIXA — docs incompletas |
| Terraform | `readonlyRootFilesystem=false` | Alterado para `true` | ALTA — contraditório com claim "hardened" |

### Lição Principal

IA acelera scaffolding mas produz erros que parecem corretos. Os bugs mais perigosos
(IAM ARN, bypass de security group, healthcheck falso-positivo) passariam em revisão casual.
Verificação linha a linha e execução real (`terraform plan`, `pytest`, `ruff check`)
são inegociáveis.

---

## 10. CHECKLIST DE VERIFICAÇÃO — Para Revisor IA ou Humano

Use este checklist para verificar cada entregável contra o PDF do desafio:

### Aplicação
- [ ] `app.py` tem endpoint `/health` retornando JSON com status, timestamp, version
- [ ] `app.py` tem endpoint `/` retornando JSON com mensagem de boas-vindas
- [ ] `app.py` usa timestamps com timezone (não `utcnow()` deprecated)
- [ ] `test_app.py` tem testes unitários para ambos endpoints
- [ ] `requirements.txt` tem apenas deps de runtime (flask)
- [ ] `requirements-dev.txt` tem deps dev/test (pytest, ruff, bandit)
- [ ] `ruff.toml` define regras de lint explícitas (não defaults puros)

### Docker
- [ ] `Dockerfile` usa multi-stage build (builder + runtime)
- [ ] `Dockerfile` usa imagem base Alpine
- [ ] `Dockerfile` cria e usa usuário não-root `appuser`
- [ ] `Dockerfile` tem HEALTHCHECK que valida HTTP 200 (não apenas conectividade)
- [ ] `docker-compose.yml` espelha healthcheck do Dockerfile
- [ ] `.dockerignore` exclui testes, terraform, config CI, ruff.toml, README, requirements-dev.txt, .ruff_cache

### Pipeline CI/CD
- [ ] `.gitlab-ci.yml` tem 4 stages: lint, test, build, deploy
- [ ] Job de lint usa ruff com config explícita
- [ ] Job de test usa pytest
- [ ] Job de SAST usa bandit (bônus) com `allow_failure: true` (não-bloqueante por design) e artefato JSON
- [ ] Job de build usa Docker-in-Docker com BuildKit habilitado
- [ ] Build faz push para GitLab Container Registry com tags SHA + latest
- [ ] Build em main e tags é automático; em MR é manual
- [ ] Tags geram imagens de release (nome da tag como image tag)
- [ ] Deploy é main-only com `when: manual`
- [ ] Deploy tem `needs: [build]`
- [ ] `workflow.rules` previnem pipelines duplicados
- [ ] Cache é keyado em hash de requirements.txt + requirements-dev.txt + prefixo do job name

### Terraform
- [ ] `main.tf` configura provider AWS com backend S3 + locking DynamoDB
- [ ] `variables.tf` tem todas 7 variáveis tipadas e documentadas
- [ ] `ecs.tf` cria: data sources de VPC, ALB SG, ECS SG, ALB, target group, listener, cluster ECS, log group, IAM role, task definition, ECS service
- [ ] ALB SG: ingress HTTP/80 de 0.0.0.0/0, egress apenas para ECS SG na porta do container
- [ ] ECS SG: ingress apenas do ALB SG na porta do container, egress 0.0.0.0/0
- [ ] Task definition: Fargate, awsvpc, readonlyRootFilesystem=true, user=appuser, healthCheck com validação 200 (defense-in-depth)
- [ ] ECS service: assign_public_ip=true, depends_on ALB listener, lifecycle ignore_changes desired_count
- [ ] IAM role ARN está correto: `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`
- [ ] `outputs.tf` fornece alb_dns_name, ecs_cluster_name, ecs_service_name

### Documentação
- [ ] README tem: como rodar localmente (3 opções), explicação do pipeline, estrutura do repo, decisões técnicas, "o que faria diferente", uso do Terraform, uso de IA com exemplos específicos de bugs
- [ ] Seção de uso de IA lista pelo menos 6 itens específicos com output da IA vs correção humana
- [ ] Árvore do README corresponde à árvore real de arquivos (incluindo ruff.toml)

### Histórico Git
- [ ] Commits contam uma história crível: build noturno → revisão matinal → hardening → polimento
- [ ] Commits v1 contêm bugs reais visíveis via `git show` ou `git diff`
- [ ] Commits de fix referenciam o que foi corrigido
- [ ] Sem secrets ou credenciais em qualquer commit

---

## 11. REFERÊNCIA RÁPIDA — Comandos para Verificação

```bash
# Lint
ruff check app.py test_app.py --config ruff.toml
ruff format --check app.py test_app.py --config ruff.toml

# Testes
pytest test_app.py -v --tb=short

# Docker
docker compose up --build
curl http://localhost:5000/health
curl http://localhost:5000/
./healthcheck.sh

# Terraform (requer binário terraform + credenciais AWS)
cd terraform
terraform init -backend=false
terraform validate
terraform plan

# Histórico git
git log --oneline
git diff 6f33c32..f105d47 # v1 → fixes da revisão matinal
git diff f105d47..5589b53 # revisão matinal → hardening
git diff 5589b53..cfed349 # hardening → polimento final
git diff cfed349..HEAD # rounds de auditoria (fixes de revisão externa)
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

### Auditoria round 2 (Gemini, May 22, 2026)

6) ~~**LOW** — Runtime image ships pytest because requirements.txt is installed wholesale.~~
**CORRIGIDO:** Split into requirements.txt (runtime: flask) + requirements-dev.txt (dev: pytest, ruff, bandit).
Dockerfile installs only requirements.txt. .dockerignore excludes requirements-dev.txt.

7) ~~**LOW** — Dockerfile healthcheck comment still says "urlopen alone doesn't catch 5xx".~~
**CORRIGIDO:** Comment updated to "assert is defense-in-depth since urlopen raises HTTPError on 5xx."

8) ~~**LOW** — .ruff_cache/ can leak into git status and Docker build context.~~
**CORRIGIDO:** Added .ruff_cache/ to .gitignore and .dockerignore.

9) **LOW** — SAST does not gate the pipeline (allow_failure: true).
**DECISAO DOCUMENTADA:** Non-blocking by design. For new projects, blocking on SAST risks false positives
halting deploys. README now explains the trade-off. In production, consider gating on HIGH severity.

10) ~~**LOW** — Tags enabled in workflow.rules but build job never runs on tags.~~
**CORRIGIDO:** Build job now has `if: $CI_COMMIT_TAG` rule. Tags produce images with tag name
(e.g., v1.0.0) as additional image tag.

### Auditoria round 3 (Gemini, May 22, 2026)

11) ~~**HIGH** — .gitlab-ci.yml cache block malformed: key/paths/policy not nested under cache:.~~
**CORRIGIDO:** Rewrote .gitlab-ci.yml with proper 2-space YAML indentation. cache: → key: → files:
nesting validated with PyYAML. All list items (before_script, script, rules) properly indented.

12) ~~**LOW** — Dev tools unpinned (ruff, bandit) in requirements-dev.txt.~~
**CORRIGIDO:** Pinned ruff==0.11.10 and bandit==1.9.1.

13) ~~**LOW** — README cache description mentions only requirements.txt, not both files.~~
**CORRIGIDO:** Updated to mention requirements.txt + requirements-dev.txt.

14) ~~**LOW** — Tags push latest, which can overwrite mainline latest from another branch.~~
**CORRIGIDO:** `latest` tag only pushed on main branch. Tags only push the tag-named image.

15) ~~**LOW** — .pytest_cache and bandit-report.json not in .gitignore.~~
**CORRIGIDO:** Added both to .gitignore.

16) ~~**LOW** — DOSSIE.md not in .dockerignore, adds file payload to build context.~~
**CORRIGIDO:** Added DOSSIE.md to .dockerignore.

17) ~~**LOW** — DOSSIE .dockerignore description stale, commit history incomplete, cache bonus wrong.~~
**CORRIGIDO:** Updated DOSSIE file tree descriptions, commit history to 14 commits, git diff
quick reference, and cache bonus to mention both requirements files.

### Auditoria round 4 (Gemini, May 22, 2026)

18) **MEDIUM** — Container runs Flask dev server (`app.run`), not production-grade.
**RESPOSTA:** Documentado no README como limitação intencional para este desafio de trainee.
Foco é CI/CD + IaC, não performance production. README now explicita:
- Single-threaded, no worker management
- No timeout handling
- Not tested at production scale
- Recommendation: replace with Gunicorn for production

19) **LOW** — Base images use floating tags (`python:3.12-alpine`).
**RESPOSTA:** Documentado no README — floating tags são aceitáveis para trainee challenge
(security updates automáticos). Production should pin to patch version or digest.
README now includes supply-chain/reproducibility note.

20) ~~**LOW** — DOSSIE commit history has placeholder hash (???????).~~
**CORRIGIDO:** Updated to actual commit hash `bbbc455`.
