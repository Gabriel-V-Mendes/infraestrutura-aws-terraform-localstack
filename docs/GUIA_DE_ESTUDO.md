# Guia Completo de Estudo: Projeto 2 — Infraestrutura AWS com OpenTofu & Floci

Este documento serve como referência técnica e material didático para estudar a reformulação do **Projeto 2 (Infraestrutura na AWS com OpenTofu e Floci)**. Ele detalha os fundamentos de **FinOps**, **Arquitetura de Rede Econômica**, **Federação de Identidade (OIDC)**, **Gerenciamento de Estado Moderno (S3 Native Locking)**, **Segurança IaC (Shift-Left)** e **Emulação Cloud Open-Source com Floci**.

---

## Sumário
1. [Filosofia da Reformulação: Do Padrão Antigo ao Cloud-Native Econômico](#1-filosofia-da-reformulação-do-padrão-antigo-ao-cloud-native-econômico)
2. [Por Dentro do Floci (`floci-io/floci`)](#2-por-dentro-do-floci-floci-iofloci)
3. [Anatomia dos 6 Módulos OpenTofu (`modules/`)](#3-anatomia-dos-6-módulos-opentofu-modules)
4. [Gerenciamento de Estado: Como Funciona o `use_lockfile = true` no S3](#4-gerenciamento-de-estado-como-funciona-o-use_lockfile--true-no-s3)
5. [Autenticação sem Chaves Estáticas: O Fluxo OIDC Passo a Passo](#5-autenticação-sem-chaves-estáticas-o-fluxo-oidc-passo-a-passo)
6. [Engenharia FinOps: Como Calcular Custos na AWS Real](#6-engenharia-finops-como-calcular-custos-na-aws-real)
7. [Laboratório Prático: "Quebre e Aprenda" & Runbooks](#7-laboratório-prático-quebre-e-aprenda--runbooks)

---

## 1. Filosofia da Reformulação: Do Padrão Antigo ao Cloud-Native Econômico

Projetos clássicos de estudo de Terraform costumam copiar tutoriais que provisionam **NAT Gateways em múltiplas AZs**, **RDS Multi-AZ** e **tabelas DynamoDB de lock**, além de autenticar pipelines com chaves estáticas (`AWS_ACCESS_KEY_ID`). Na vida real:
- Um único **NAT Gateway** custa **US$ 0,045/hora (~US$ 32,85/mês)** mais **US$ 0,045 por GB processado**, mesmo sem tráfego.
- Chaves IAM estáticas esquecidas em variáveis de CI são o vetor número 1 de comprometimento de contas AWS.
- O **OpenTofu 1.10+** e o **Terraform 1.10+** já fazem lock nativo no próprio S3 (`use_lockfile = true`), tornando o DynamoDB desnecessário para controle de concorrência do state.

---

## 2. Por Dentro do Floci (`floci-io/floci`)

O **[Floci](https://github.com/floci-io/floci)** é um emulador local da AWS compilado nativamente com **Quarkus + GraalVM Mandrel**:
- **Porta única (`4566`):** Todos os serviços AWS respondem em `http://localhost:4566` usando o protocolo wire real da AWS (REST XML, Query XML, JSON 1.1).
- **Zero Lock-in Comercial:** Licença MIT, sem necessidade de conta, sem token de autenticação e sem recursos bloqueados.
- **Modos de Execução (`docker-compose.yml`):**
  - `FLOCI_STORAGE_MODE=memory`: Estado rápido em memória para testes de CI/CD limpos.
  - `FLOCI_SERVICES_EC2_MOCK=true` / `FLOCI_SERVICES_RDS_MOCK=true`: Valida todo o plano de controle da AWS (VPC, SGs, ASG, ALB, RDS, IAM, Budgets, S3, KMS) em segundos dentro do GitHub Actions sem exigir Docker-in-Docker privilegiado. Quando configurado como `false` com `/var/run/docker.sock` montado, o Floci sobe containers Docker reais para cada instância EC2 e banco RDS PostgreSQL.

---

## 3. Anatomia dos 6 Módulos OpenTofu (`modules/`)

### 3.1 `modules/budget-alerts` — Orçamento e Alertas Vêm Antes de Tudo
Nenhuma infraestrutura deve subir sem visibilidade financeira e operacional:
- **`aws_budgets_budget.monthly_cost`:** Define um teto mensal (`US$ 15.00` por padrão) e dispara notificações automáticas em **50% (gasto real)**, **80% (gasto real)** e **100% (gasto projetado/forecasted)**.
- **`aws_sns_topic.alerts`:** Tópico SNS criptografado com KMS (`kms_master_key_id`) que centraliza o envio de alertas por e-mail.
- **`aws_cloudwatch_metric_alarm.cpu_high`:** Monitora `CPUUtilization` na EC2 e aciona o tópico SNS caso a média ultrapasse 80% por 2 períodos consecutivos.

### 3.2 `modules/iam-oidc` — Identidade Federada e Menor Privilégio
- **`aws_iam_openid_connect_provider.github_actions`:** Registra o emissor `https://token.actions.githubusercontent.com` na conta AWS.
- **`aws_iam_role.github_actions_oidc`:** Role assumida via `sts:AssumeRoleWithWebIdentity` com condição estrita:
  ```hcl
  Condition = {
    StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
    }
    StringLike = {
      "token.actions.githubusercontent.com:sub" = "repo:Gabriel-V-Mendes/infraestrutura-aws-terraform-localstack:*"
    }
  }
  ```
- **`aws_iam_role.ec2_app` & `aws_iam_instance_profile.ec2_app`:** Permite que a instância EC2 leia a `DATABASE_URL` no Secrets Manager e acesse o bucket S3 da aplicação sem nenhuma credencial salva no disco da máquina.

### 3.3 `modules/storage` — Criptografia KMS e S3 Blindado
- **`aws_kms_key.main`:** Customer Managed Key (CMK) com rotação anual automática (`enable_key_rotation = true`).
- **`aws_s3_bucket.artifacts`:** Configurado com versionamento (`Enabled`), criptografia KMS (`aws:kms` + `bucket_key_enabled = true` para reduzir custos de chamadas ao KMS), bloqueio total das 4 flags de acesso público (`aws_s3_bucket_public_access_block`) e regra de ciclo de vida (`lifecycle`) que limpa versões antigas após 30 dias e uploads multipart incompletos após 7 dias.

### 3.4 `modules/network` — Rede Econômica com Security Groups em 3 Camadas
```text
[Internet] ──(TCP 80/443)──▶ [alb-sg (ALB)] ──(TCP 8000)──▶ [app-sg (EC2)] ──(TCP 5432)──▶ [db-sg (RDS)]
```
- **Por que não precisamos de NAT Gateway aqui?**
  Na AWS, uma instância ou banco em uma subnet com rota para o Internet Gateway **só é acessível pela internet se possuir IP público E se o seu Security Group permitir tráfego de entrada**.
  - O **RDS (`db-sg`)** tem `publicly_accessible = false` (não recebe IP público) e seu Security Group aceita conexões na porta `5432` **exclusivamente** de recursos que pertençam ao `app-sg`.
  - A **EC2 (`app-sg`)** recebe IP público apenas no Launch Template para poder fazer `docker pull` da imagem no GHCR (saída `443`), mas seu Security Group bloqueia qualquer conexão direta da internet, aceitando entrada na porta `8000` **exclusivamente** do `alb-sg`.

### 3.5 `modules/database` — RDS PostgreSQL 17.2 Single-AZ + Secrets Manager
- **`aws_db_instance.postgres`:** Provisiona um PostgreSQL 17.2 real (`db.t4g.micro`, `multi_az = false`, disco `gp3` criptografado com KMS, autenticação IAM habilitada e `skip_final_snapshot = true` nos testes).
- **`aws_secretsmanager_secret.database_url`:** Monta automaticamente a connection string `postgresql+psycopg://usuario:senha@host:5432/devops` assim que o RDS fica pronto, integrando-se diretamente com a API FastAPI do Projeto 1.

### 3.6 `modules/compute` — ALB (`/health/ready`) + Launch Template + Auto Scaling (1 Instância)
- **`aws_lb.app` & `aws_lb_target_group.app`:** O Load Balancer verifica a saúde da instância chamando `GET /health/ready` na porta `8000` (o endpoint que testa a conexão real com o PostgreSQL).
- **`aws_launch_template.app`:** Exige **IMDSv2** (`http_tokens = "required"`, mitigando ataques de SSRF que tentam roubar credenciais da instância), criptografa o volume EBS `gp3` de 20 GiB com KMS e executa o [`user_data.sh.tpl`](../modules/compute/user_data.sh.tpl) para subir o container da FastAPI sem root (`--read-only`, `--cap-drop ALL`).
- **`aws_autoscaling_group.app`:** Mantém `desired_capacity = 1` (`min_size = 1`, `max_size = 1`). Se a instância falhar no healthcheck do ALB, o Auto Scaling a substitui automaticamente sem custo extra de instância ociosa.

---

## 4. Gerenciamento de Estado: Como Funciona o `use_lockfile = true` no S3

```mermaid
sequenceDiagram
    participant Dev as OpenTofu CLI
    participant S3 as S3 Bucket (devops-api-tofu-state)

    Dev->>S3: PUT floci-local/terraform.tfstate.tflock (Header: If-None-Match: *)
    alt Nenhum lock ativo
        S3-->>Dev: 200 OK (Lock adquirido!)
        Dev->>S3: GET floci-local/terraform.tfstate
        Dev->>Dev: Executa Plan / Apply
        Dev->>S3: PUT floci-local/terraform.tfstate (Nova versão)
        Dev->>S3: DELETE floci-local/terraform.tfstate.tflock (Libera o lock)
    else Outro job já está rodando
        S3-->>Dev: 412 Precondition Failed (State bloqueado!)
    end
```

---

## 5. Autenticação sem Chaves Estáticas: O Fluxo OIDC Passo a Passo

```mermaid
sequenceDiagram
    participant GHA as GitHub Actions Runner
    participant IdP as GitHub OIDC Provider
    participant STS as AWS STS (ou Floci STS :4566)
    participant AWS as Recursos AWS

    GHA->>IdP: Solicita JWT assinado (permissions: id-token: write)
    IdP-->>GHA: Retorna JWT (iss: token.actions.githubusercontent.com, sub: repo:owner/repo:...)
    GHA->>STS: AssumeRoleWithWebIdentity (RoleArn + WebIdentityToken)
    STS->>STS: Valida assinatura do IdP + Condição sub/aud da Trust Policy
    STS-->>GHA: Credenciais temporárias (AccessKeyId + SecretAccessKey + SessionToken)
    GHA->>AWS: Executa OpenTofu com credenciais efêmeras (expiram ao fim do job)
```

---

## 6. Engenharia FinOps: Como Calcular Custos na AWS Real

Para calcular o custo de qualquer arquitetura na AWS antes de provisionar:
1. **Identifique os recursos cobrados por hora de existência (mesmo ociosos):**
   - Instâncias EC2 (`t3.micro` = US$ 0,0104/h em `us-east-1`)
   - Endereços IPv4 públicos alocados/em uso (`US$ 0,005/h` = US$ 3,65/mês por IPv4 público desde fev/2024!)
   - Application Load Balancer (`US$ 0,0225/h` fixo + LCU)
   - Instância RDS Single-AZ (`db.t4g.micro` = US$ 0,0160/h)
   - NAT Gateway (`US$ 0,045/h` — **eliminado neste projeto!**)
2. **Identifique os recursos cobrados por GB-mês ou por unidade fixa mensal:**
   - Volumes EBS `gp3` (`US$ 0,08/GB-mês`) e armazenamento RDS `gp3` (`US$ 0,115/GB-mês`)
   - Chaves KMS Customer Managed (`US$ 1,00/mês` por chave)
   - Segredos no Secrets Manager (`US$ 0,40/mês` por segredo)

---

## 7. Laboratório Prático: "Quebre e Aprenda" & Runbooks

### Experimento 1: Testar o bloqueio do `trivy config` (Shift-Left Security)
1. Abra `modules/compute/main.tf` e mude `http_tokens = "required"` para `http_tokens = "optional"`.
2. Rode `make scan`.
3. **Resultado:** O Trivy falha imediatamente com `AWS-0028 (HIGH): Instance does not require IMDS access to require a token` e código de saída `1`, impedindo que a vulnerabilidade chegue ao Pull Request.
4. Reverta com `git checkout -- modules/compute/main.tf`.

### Experimento 2: Simular falha de arquitetura de AMI vs. Instância no Floci
1. Em `environments/floci-local/terraform.tfvars`, mude `ec2_instance_type = "t3.micro"` (x86_64) para `"t4g.micro"` (ARM64 Graviton) mantendo a AMI `x86_64`.
2. Rode `make apply`.
3. **Resultado:** O reconciliador de Auto Scaling do Floci reproduz a validação exata da AWS:
   `The architecture 'x86_64' of the specified image does not match the architecture supported by instance type 't4g.micro'`.

### Runbook: Destravar um State Lock Órfão (`.tflock`)
Se uma execução do OpenTofu for interrompida abruptamente (ex.: queda de energia ou `kill -9`) e deixar um `.tflock` órfão no S3:
```bash
# Verifique o lock ou remova usando o comando nativo do OpenTofu:
cd environments/floci-local
tofu force-unlock -force <LOCK_ID>
```
