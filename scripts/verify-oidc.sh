#!/usr/bin/env bash
# Valida a autenticação OIDC sem chaves estáticas (sts:AssumeRoleWithWebIdentity)
# diretamente contra o STS emulado da Floci!
set -euo pipefail

FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ROLE_NAME="${ROLE_NAME:-devops-api-floci-gha-oidc-role}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-floci-ephemeral}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-floci-ephemeral}"
export AWS_DEFAULT_REGION="$AWS_REGION"

aws_floci() {
  aws --endpoint-url "$FLOCI_ENDPOINT" --region "$AWS_REGION" --no-cli-pager --output json "$@"
}

echo "==> [OIDC] Consultando Role OIDC provisionada pelo OpenTofu..."
ROLE_ARN=$(aws_floci iam get-role --role-name "$ROLE_NAME" | jq -r '.Role.Arn')
echo "    Role encontrada: $ROLE_ARN"

# Gera um JWT OIDC sintético representando o token emitido pelo GitHub Actions
# (iss: https://token.actions.githubusercontent.com, sub: repo:Gabriel-V-Mendes/infraestrutura-aws-terraform-localstack:ref:refs/heads/main)
HEADER=$(printf '{"alg":"none","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(printf '{"iss":"https://token.actions.githubusercontent.com","sub":"repo:Gabriel-V-Mendes/infraestrutura-aws-terraform-localstack:ref:refs/heads/main","aud":"sts.amazonaws.com","exp":9999999999}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
MOCK_OIDC_JWT="${HEADER}.${PAYLOAD}.signature"

echo "==> [OIDC] Executando sts:AssumeRoleWithWebIdentity na Floci..."
STS_OUTPUT=$(aws_floci sts assume-role-with-web-identity \
  --role-arn "$ROLE_ARN" \
  --role-session-name "github-actions-oidc-ci" \
  --web-identity-token "$MOCK_OIDC_JWT")

TEMP_KEY_ID=$(echo "$STS_OUTPUT" | jq -r '.Credentials.AccessKeyId')
TEMP_TOKEN=$(echo "$STS_OUTPUT" | jq -r '.Credentials.SessionToken')
ASSUMED_ARN=$(echo "$STS_OUTPUT" | jq -r '.AssumedRoleUser.Arn')

if [[ -z "$TEMP_KEY_ID" || "$TEMP_KEY_ID" == "null" || -z "$TEMP_TOKEN" ]]; then
  echo "ERRO: Falha ao obter credenciais temporárias via OIDC!" >&2
  exit 1
fi

echo "    AssumedRoleUser: $ASSUMED_ARN"
echo "    Temporary AccessKeyId prefix: ${TEMP_KEY_ID:0:8}*** (com SessionToken efêmero)"
echo "==> [OIDC] Federação OIDC validada com sucesso (Zero chaves estáticas!)."
