#!/usr/bin/env bash
# Cria o bucket S3 de state no Floci (ou AWS) com versionamento habilitado
# antes do `tofu init` com lock nativo (`use_lockfile = true`).
set -euo pipefail

FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STATE_BUCKET="${STATE_BUCKET:-devops-api-tofu-state}"

# Credenciais efêmeras de sessão apenas para a camada de emulação local da Floci
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-floci-ephemeral}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-floci-ephemeral}"
export AWS_DEFAULT_REGION="$AWS_REGION"

aws_floci() {
  aws --endpoint-url "$FLOCI_ENDPOINT" --region "$AWS_REGION" --no-cli-pager "$@"
}

echo "==> [Bootstrap] Verificando bucket S3 de state '$STATE_BUCKET' em $FLOCI_ENDPOINT..."
if ! aws_floci s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  aws_floci s3api create-bucket --bucket "$STATE_BUCKET" >/dev/null
  echo "    Bucket '$STATE_BUCKET' criado."
else
  echo "    Bucket '$STATE_BUCKET' já existe."
fi

aws_floci s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

echo "==> [Bootstrap] Bucket '$STATE_BUCKET' pronto para state + lock nativo (.tflock)."
