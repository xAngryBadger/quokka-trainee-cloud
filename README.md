# Trainee Cloud & IA — Desafio Técnico

API Flask de health check com pipeline CI/CD completo, containerização Docker e infraestrutura como código para deploy no AWS ECS.

---

## Como Rodar a Aplicação Localmente

### Opção 1: Docker Compose (recomendado)

```bash
docker compose up --build
```

A aplicação estará disponível em `http://localhost:5000`.

### Opção 2: Docker Manual

```bash
docker build -t trainee-devops-api .
docker run -d -p 5000:5000 --name trainee-api trainee-devops-api
```

### Opção 3: Python Direto

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

### Verificando a Aplicação

```bash
curl http://localhost:5000/health
curl http://localhost:5000/
```

Ou use o script de healthcheck:

```bash
chmod +x healthcheck.sh
./healthcheck.sh
./healthcheck.sh localhost 5000
```

### Rodar os testes localmente

```bash
pip install -r requirements.txt
pytest test_app.py -v
```

---

## Como o Pipeline Funciona

O pipeline `.gitlab-ci.yml` possui 4 stages sequenciais + 1 job bonus de segurança:

### Stage 1: Lint

- **Ferramenta:** `ruff` — linter Python moderno, 10-100x mais rápido que flake8
- **O que faz:** Analisa `app.py` e `test_app.py` buscando erros de estilo, imports não utilizados e más práticas
- **Critério de falha:** Job falha se o ruff encontrar qualquer violação

### Stage 2: Test

- **Ferramenta:** `pytest`
- **O que faz:** Executa os testes unitários em `test_app.py` validando os endpoints `/health` e `/`
- **Critério de falha:** Job falha se qualquer teste não passar

### Stage 2 (bonus): SAST — Security Scan

- **Ferramenta:** `bandit`
- **O que faz:** Análise estática de segurança no código Python
- **Artefato:** Gera `bandit-report.json` para análise posterior

### Stage 3: Build

- **Ferramenta:** Docker (Docker-in-Docker)
- **O que faz:** Constrói a imagem Docker e faz push para o GitLab Container Registry
- **Variáveis utilizadas:** `$CI_REGISTRY`, `$CI_REGISTRY_USER`, `$CI_REGISTRY_PASSWORD` (predefinidas pelo GitLab)

### Stage 4: Deploy

- **O que faz:** Simula o deploy no AWS ECS imprimindo os comandos que seriam executados
- **Quando roda:** Apenas na branch `main`

---

## Estrutura do Repositório

```
.
├── app.py              # Aplicação Flask
├── test_app.py         # Testes unitários
├── requirements.txt    # Dependências Python
├── Dockerfile          # Containerização com multi-stage build
├── docker-compose.yml  # Compose para rodar localmente
├── healthcheck.sh      # Script de verificação de saúde
├── .gitlab-ci.yml      # Pipeline CI/CD
├── .dockerignore       # Arquivos ignorados no build Docker
├── .gitignore          # Arquivos ignorados pelo Git
└── terraform/
    ├── main.tf         # Provider AWS e backend S3
    ├── variables.tf    # Variáveis do Terraform
    ├── ecs.tf          # Recursos ECS, ALB, IAM, CloudWatch
    └── outputs.tf      # Outputs da infraestrutura
```

---

## Decisões Técnicas

### Dockerfile — Multi-stage Build

Separação entre ambiente de build (com pip, cache de downloads) e runtime (apenas o necessário para rodar). O stage `builder` instala dependências em `/install`, e o runtime copia apenas o resultado. Isso exclui cache do pip e ferramentas de build da imagem final, reduzindo tamanho e superfície de ataque.

### Imagem Base — python:3.12-alpine

Alpine (~50MB base) vs slim (~120MB base). Para uma API Flask simples sem dependências nativas, Alpine é suficiente. Menos pacotes = menor superfície de ataque.

### Usuário Não-root

Container roda como `appuser`. Se um atacante comprometer a aplicação, terá acesso limitado — sem privilégios de root.

### Linter — ruff em vez de flake8

Ruff é 10-100x mais rápido que flake8, tem regras compatíveis e é o padrão moderno da comunidade Python. Em um pipeline CI/CD, velocidade importa.

### Terraform — Simplificado mas Funcional

A configuração cria infraestrutura ECS completa (cluster, service, task definition, ALB com target group, security groups, IAM roles, CloudWatch logs). Usa a VPC default para simplificar, mas reconheço que em produção isso é inseguro (veja "O que faria diferente").

---

## O Que Eu Faria Diferente com Mais Tempo

1. **VPC dedicada com subnets privadas** — A configuração atual usa a VPC default com subnets públicas. Em produção, os containers ECS rodariam em subnets privadas, acessíveis apenas via ALB nas subnets públicas.

2. **Pipeline de deploy real** — Implementaria deploy efetivo no ECS com AWS CLI, incluindo rollback automático se o health check pós-deploy falhar.

3. **Staging environment** — Environment de staging que recebe deploy automático a cada merge na main, antes do deploy em produção.

4. **Auto-scaling** — Configuraria auto-scaling do ECS Service baseado em CPU e memória.

5. **Container registry scanning** — Trivy ou ECR image scanning antes do deploy, bloqueando imagens com vulnerabilidades críticas.

6. **Secrets management** — AWS Secrets Manager ou SSM Parameter Store para secrets.

7. **Monitoring e alerting** — CloudWatch Alarms para latência, erros 5xx e health check failures, com notificações via SNS.

8. **Pipeline para o Terraform** — `terraform fmt -check`, `terraform validate` e `terraform plan` como jobs do pipeline.

9. **Testes de integração** — Testes que sobem o container Docker e fazem requests reais contra a API.

10. **HTTPS no ALB** — Adicionar certificado ACM + listener HTTPS (porta 443) com redirect HTTP→HTTPS.

---

## Como Usar o Terraform

### Pré-requisitos

- Terraform >= 1.5.0 instalado
- Credenciais AWS configuradas (`aws configure` ou variáveis de ambiente)
- Bucket S3 `terraform-state-trainee` criado para o backend (ou ajuste o `backend` em `main.tf` para local)

### Comandos

```bash
cd terraform

# Inicializa (baixa providers, configura backend)
terraform init

# Visualiza o que será criado
terraform plan

# Aplica a infraestrutura
terraform apply

# Para destruir (custo!)
terraform destroy
```

### Variáveis

| Variável | Default | Descrição |
|-----------|---------|-----------|
| `aws_region` | `us-east-1` | Região AWS |
| `environment` | `production` | Ambiente de deploy |
| `app_name` | `trainee-devops-api` | Nome da aplicação |
| `container_image` | `registry.gitlab.com/...` | Imagem Docker para o ECS |
| `container_port` | `5000` | Porta do container |
| `cpu` | `256` | CPU units (Fargate) |
| `memory` | `512` | Memória MiB (Fargate) |
| `desired_count` | `2` | Número de tasks ECS |

---

## Como Usei IA Durante o Desafio

### Ferramenta

Utilizei o **opencode** (CLI de IA para engenharia de software) com o modelo **GLM-5.1** como assistente durante todo o processo.

### O que pedi a IA

1. **Dockerfile** — Geração inicial com multi-stage build, usuário não-root e healthcheck.
2. **Pipeline CI/CD** — Geração da estrutura base do `.gitlab-ci.yml`.
3. **Terraform para ECS** — Geração dos recursos principais.
4. **Docker Compose e healthcheck.sh** — Geração dos arquivos auxiliares.
5. **README** — Geração da estrutura de documentação.

### O que funcionou bem

- **Boilerplate e scaffolding** — A IA é excelente para gerar a estrutura inicial de arquivos de configuração.
- **Velocidade** — O que tomaria horas de pesquisa e escrita foi gerado em minutos.

### O que não funcionou tão bem

- A gerar alguns detalhes específicos que precisei corrigir manualmente após revisão.

### Aprendizados

- IA é uma aceleradora, não um substituto para revisão manual cuidadosa.
