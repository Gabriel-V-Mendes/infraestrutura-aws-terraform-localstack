#!/usr/bin/env bash
set -euo pipefail

# Bootstrap da instância EC2 (Amazon Linux 2023) para rodar a API FastAPI do Projeto 1
dnf update -y
dnf install -y docker jq awscli
systemctl enable --now docker

# Busca a DATABASE_URL no Secrets Manager usando o Instance Profile (sem credenciais estáticas!)
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${database_url_secret_arn}" \
  --query SecretString \
  --output text)

DATABASE_URL=$(echo "$SECRET_JSON" | jq -r '.DATABASE_URL')

# Executa a imagem imutável publicada no GHCR com os mesmos controles de hardening do Projeto 1
docker pull "${app_image}"
docker run -d \
  --name devops-api \
  --restart unless-stopped \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  -p 8000:8000 \
  -e DATABASE_URL="$DATABASE_URL" \
  -e APP_VERSION="${environment}" \
  "${app_image}"
