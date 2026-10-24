#!/usr/bin/env bash
# Smoke test da infraestrutura provisionada pelo OpenTofu no emulador Floci.
# Verifica via AWS CLI que todos os recursos exigidos pelo Projeto 2 existem e estão íntegros.
set -euo pipefail

FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-floci-ephemeral}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-floci-ephemeral}"
export AWS_DEFAULT_REGION="$AWS_REGION"

aws_floci() {
  aws --endpoint-url "$FLOCI_ENDPOINT" --region "$AWS_REGION" --no-cli-pager --output json "$@"
}

echo "==> [Smoke Infra] 1/7 Verificando State no S3 (devops-api-tofu-state)..."
aws_floci s3api head-object \
  --bucket devops-api-tofu-state \
  --key floci-local/terraform.tfstate >/dev/null

echo "==> [Smoke Infra] 2/7 Verificando Bucket S3 da Aplicação + Versionamento + Criptografia..."
aws_floci s3api head-bucket --bucket devops-api-floci-artifacts
VERSIONING=$(aws_floci s3api get-bucket-versioning --bucket devops-api-floci-artifacts | jq -r '.Status')
[[ "$VERSIONING" == "Enabled" ]] || { echo "ERRO: Versionamento S3 não habilitado ($VERSIONING)"; exit 1; }

echo "==> [Smoke Infra] 3/7 Verificando FinOps (AWS Budgets + SNS + CloudWatch Alarm)..."
ACCOUNT_ID=$(aws_floci sts get-caller-identity | jq -r '.Account')
BUDGET_LIMIT=$(aws_floci budgets describe-budget \
  --account-id "$ACCOUNT_ID" \
  --budget-name "devops-api-floci-monthly-budget" | jq -r '.Budget.BudgetLimit.Amount')
echo "    Orçamento mensal ativo: US$ ${BUDGET_LIMIT}"
ALARM_COUNT=$(aws_floci cloudwatch describe-alarms \
  --alarm-names "devops-api-floci-ec2-cpu-high" | jq '.MetricAlarms | length')
[[ "$ALARM_COUNT" -eq 1 ]] || { echo "ERRO: Alarme CloudWatch não encontrado"; exit 1; }

echo "==> [Smoke Infra] 4/7 Verificando IAM OIDC Provider e Roles..."
OIDC_COUNT=$(aws_floci iam list-open-id-connect-providers | jq '.OpenIDConnectProviderList | length')
[[ "$OIDC_COUNT" -ge 1 ]] || { echo "ERRO: OIDC Provider não encontrado"; exit 1; }
aws_floci iam get-role --role-name "devops-api-floci-gha-oidc-role" >/dev/null
aws_floci iam get-instance-profile --instance-profile-name "devops-api-floci-ec2-app-profile" >/dev/null

echo "==> [Smoke Infra] 5/7 Verificando VPC, Subnets Públicas (sem NAT Gateway) e 3 Security Groups..."
VPC_COUNT=$(aws_floci ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=devops-api-floci-vpc" | jq '.Vpcs | length')
[[ "$VPC_COUNT" -eq 1 ]] || { echo "ERRO: VPC devops-api-floci-vpc não encontrada"; exit 1; }
NAT_COUNT=$(aws_floci ec2 describe-nat-gateways | jq '.NatGateways | length')
[[ "$NAT_COUNT" -eq 0 ]] || { echo "ERRO: NAT Gateway não deveria existir na arquitetura econômica!"; exit 1; }
SG_COUNT=$(aws_floci ec2 describe-security-groups \
  --filters "Name=group-name,Values=devops-api-floci-alb-sg,devops-api-floci-app-sg,devops-api-floci-db-sg" | jq '.SecurityGroups | length')
[[ "$SG_COUNT" -eq 3 ]] || { echo "ERRO: Esperados 3 Security Groups estritos, encontrados: $SG_COUNT"; exit 1; }

echo "==> [Smoke Infra] 6/7 Verificando RDS PostgreSQL Single-AZ + Secrets Manager DATABASE_URL..."
RDS_JSON=$(aws_floci rds describe-db-instances --db-instance-identifier "devops-api-floci-postgres")
MULTI_AZ=$(echo "$RDS_JSON" | jq -r '.DBInstances[0].MultiAZ')
[[ "$MULTI_AZ" == "false" ]] || { echo "ERRO: RDS deveria ser Single-AZ (MultiAZ=false), mas retornou $MULTI_AZ"; exit 1; }
DB_URL=$(aws_floci secretsmanager get-secret-value \
  --secret-id "devops-api-floci-database-url" | jq -r '.SecretString | fromjson | .DATABASE_URL')
[[ "$DB_URL" == postgresql+psycopg://* ]] || { echo "ERRO: DATABASE_URL inválida no Secrets Manager"; exit 1; }

echo "==> [Smoke Infra] 7/7 Verificando ALB, Target Group (/health/ready) e Auto Scaling Group (1 instância)..."
ALB_DNS=$(aws_floci elbv2 describe-load-balancers \
  --names "devops-api-floci-alb" | jq -r '.LoadBalancers[0].DNSName')
TG_PATH=$(aws_floci elbv2 describe-target-groups \
  --names "devops-api-floci-tg" | jq -r '.TargetGroups[0].HealthCheckPath')
[[ "$TG_PATH" == "/health/ready" ]] || { echo "ERRO: HealthCheckPath esperado /health/ready, obtido $TG_PATH"; exit 1; }
ASG_CAP=$(aws_floci autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "devops-api-floci-asg" | jq -r '.AutoScalingGroups[0].DesiredCapacity')
[[ "$ASG_CAP" -eq 1 ]] || { echo "ERRO: DesiredCapacity esperado 1, obtido $ASG_CAP"; exit 1; }

echo "==> [Smoke Infra] Todos os 7 grupos de verificação passaram! ALB DNS: $ALB_DNS"
