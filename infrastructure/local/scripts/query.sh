#!/usr/bin/env bash
# Run a saved clickhouse-local query against the CloudFront access-log bucket.
#
# Usage:
#   ./scripts/query.sh top-paths [prefix]
#   ./scripts/query.sh status-breakdown blog.paulserban.eu
#   ./scripts/query.sh cache-hit-ratio
#   ./scripts/query.sh referrers quiz.paulserban.eu
#
# Requires: Docker, and infrastructure/local/.env with AWS credentials + CF_LOG_BUCKET.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
QUERIES_DIR="${LOCAL_DIR}/clickhouse/queries"

QUERY_NAME="${1:-}"
PREFIX="${2:-paulserban.eu}"

if [[ -z "${QUERY_NAME}" ]]; then
  echo "Usage: $0 <query-name> [log-prefix]" >&2
  echo "Available queries:" >&2
  ls -1 "${QUERIES_DIR}"/*.sql | xargs -n1 basename | sed 's/\.sql$//' >&2
  exit 1
fi

QUERY_FILE="${QUERIES_DIR}/${QUERY_NAME}.sql"
if [[ ! -f "${QUERY_FILE}" ]]; then
  echo "Unknown query: ${QUERY_NAME}" >&2
  echo "Expected file: ${QUERY_FILE}" >&2
  exit 1
fi

ENV_FILE="${LOCAL_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE} — copy .env.example and fill AWS credentials." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID required in .env}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY required in .env}"
: "${CF_LOG_BUCKET:?CF_LOG_BUCKET required in .env}"

REGION="${CF_LOG_REGION:-${AWS_REGION:-eu-central-1}}"
# Prefix should end without trailing slash in path segment; CloudFront logs under prefix/
S3_URL="https://${CF_LOG_BUCKET}.s3.${REGION}.amazonaws.com/${PREFIX}/*.gz"

SQL="$(
  sed \
    -e "s|__S3_URL__|${S3_URL}|g" \
    -e "s|__AWS_KEY__|${AWS_ACCESS_KEY_ID}|g" \
    -e "s|__AWS_SECRET__|${AWS_SECRET_ACCESS_KEY}|g" \
    "${QUERY_FILE}"
)"

echo "# query=${QUERY_NAME} prefix=${PREFIX} bucket=${CF_LOG_BUCKET}" >&2
echo "# Note: CloudFront standard logs can lag by minutes–hours after enabling." >&2

docker run --rm \
  clickhouse/clickhouse-server:24.12 \
  clickhouse-local \
  --query "${SQL}" \
  --format PrettyCompact
